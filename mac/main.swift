import Cocoa
import WebKit
import UserNotifications

/* ───────── 주간 업무 플래너 · macOS 앱 셸 ─────────
   index.html 을 WKWebView 로 띄우고, 웹에서 못 하는 일(파일 저장·열기, 항상 위, 미니 모드)을 대신한다.
   데이터는 ~/Library/Application Support/WeeklyPlanner/data.json 에 저장된다. */

let appName = "주간 업무 플래너"
let dataDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
    .appendingPathComponent("WeeklyPlanner", isDirectory: true)
let dataFile = dataDir.appendingPathComponent("data.json")

/* index.html 이 PC 앱에서 기대하는 window.electronAPI 를 WKWebView 용으로 재현 */
let bridgeJS = """
(function () {
  if (window.electronAPI) return;
  var post = function (name, obj) { window.webkit.messageHandlers[name].postMessage(JSON.stringify(obj)); };
  window.electronAPI = {
    setAlwaysOnTop: async function (on) { post('ui', { type: 'alwaysOnTop', on: !!on }); },
    setMiniMode: async function (on, pinned) { post('ui', { type: 'miniMode', on: !!on, pinned: !!pinned }); },
    flashFrame: async function () { post('ui', { type: 'flash' }); },
    fetchHolidays: async function (key, year) {
      try {
        var k = key.indexOf('%') >= 0 ? key : encodeURIComponent(key);
        var url = 'https://apis.data.go.kr/B090041/openapi/service/SpcdeInfoService/getRestDeInfo'
          + '?serviceKey=' + k + '&solYear=' + year + '&numOfRows=100&_type=json';
        var r = await fetch(url);
        if (!r.ok) return { ok: false, error: 'HTTP ' + r.status };
        var j = await r.json();
        var body = j && j.response && j.response.body;
        var items = body && body.items && body.items.item;
        if (!items) items = [];
        if (!Array.isArray(items)) items = [items];
        var holidays = {};
        for (var i = 0; i < items.length; i++) {
          var d = String(items[i].locdate || '');
          if (d.length === 8) holidays[d.slice(0, 4) + '-' + d.slice(4, 6) + '-' + d.slice(6, 8)] = String(items[i].dateName || '공휴일');
        }
        return { ok: true, holidays: holidays };
      } catch (e) { return { ok: false, error: String(e && e.message || e) }; }
    }
  };
})();
"""

final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate,
                         WKScriptMessageHandler, WKNavigationDelegate, WKUIDelegate, WKDownloadDelegate,
                         UNUserNotificationCenterDelegate {
    var window: NSWindow!
    var webView: WKWebView!
    var pinned = false
    var mini = false
    var normalFrame: NSRect?
    let normalMinSize = NSSize(width: 960, height: 600)

    func applicationDidFinishLaunching(_ notification: Notification) {
        try? FileManager.default.createDirectory(at: dataDir, withIntermediateDirectories: true)

        let ucc = WKUserContentController()
        ucc.add(self, name: "save")
        ucc.add(self, name: "ui")

        var json = "null"
        if let d = try? Data(contentsOf: dataFile), let s = String(data: d, encoding: .utf8), !s.isEmpty {
            json = s
        }
        let b64 = Data(json.utf8).base64EncodedString()
        ucc.addUserScript(WKUserScript(
            source: "window.__INITIAL_DATA_B64__ = \"\(b64)\";",
            injectionTime: .atDocumentStart, forMainFrameOnly: true))
        ucc.addUserScript(WKUserScript(source: bridgeJS, injectionTime: .atDocumentStart, forMainFrameOnly: true))

        let config = WKWebViewConfiguration()
        config.userContentController = ucc
        config.mediaTypesRequiringUserActionForPlayback = []
        // file:// 로 로드된 페이지에서 GitHub API(동기화)·공휴일 API(https) fetch 를 허용
        config.setValue(true, forKey: "allowUniversalAccessFromFileURLs")

        webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.setValue(false, forKey: "drawsBackground")

        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1440, height: 900),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered, defer: false)
        window.title = appName
        window.minSize = normalMinSize
        window.contentView = webView
        window.delegate = self
        window.isReleasedWhenClosed = false
        window.center()
        window.setFrameAutosaveName("WeeklyPlannerMain")
        window.makeKeyAndOrderFront(nil)

        if let url = Bundle.main.url(forResource: "index", withExtension: "html") {
            webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
        }

        let center = UNUserNotificationCenter.current()
        center.delegate = self
        center.requestAuthorization(options: [.alert, .sound]) { _, _ in }
        if json != "null" { scheduleRoutineNotifications(json: json) }

        NSApp.activate(ignoringOtherApps: true)
    }

    /* ── 시간이 있는 반복 업무 → 맥 기본 알림 (매일/매주/매달 반복) ── */
    func scheduleRoutineNotifications(json: String) {
        guard let d = json.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: d) as? [String: Any] else { return }
        let recur = obj["recur"] as? [[String: Any]] ?? []
        let center = UNUserNotificationCenter.current()
        center.getPendingNotificationRequests { pending in
            let old = pending.map { $0.identifier }.filter { $0.hasPrefix("routine-") }
            center.removePendingNotificationRequests(withIdentifiers: old)
            var count = 0
            for r in recur {
                guard let time = r["time"] as? String,
                      (r["alarm"] as? Bool) ?? true,
                      let id = r["id"] as? String,
                      let text = r["text"] as? String else { continue }
                let parts = time.split(separator: ":").compactMap { Int($0) }
                guard parts.count == 2 else { continue }
                let hour = parts[0], minute = parts[1]
                let freq = r["freq"] as? String ?? "daily"
                var comps: [DateComponents] = []
                if freq == "daily" {
                    comps.append(DateComponents(hour: hour, minute: minute))
                } else if freq == "weekly" {
                    // 플래너는 월요일=0 … 일요일=6, Apple 은 일요일=1 … 토요일=7
                    for w in (r["weekdays"] as? [Int]) ?? [] {
                        comps.append(DateComponents(hour: hour, minute: minute, weekday: w == 6 ? 1 : w + 2))
                    }
                } else if freq == "monthly", let day = r["monthday"] as? Int {
                    comps.append(DateComponents(day: day, hour: hour, minute: minute))
                }
                for (i, c) in comps.enumerated() {
                    if count >= 60 { return } // 시스템 예약 알림 개수 제한(64) 보호
                    let content = UNMutableNotificationContent()
                    content.title = "⏰ " + text
                    content.body = "지금 할 시간이에요"
                    content.sound = .default
                    let trigger = UNCalendarNotificationTrigger(dateMatching: c, repeats: true)
                    center.add(UNNotificationRequest(identifier: "routine-\(id)-\(i)", content: content, trigger: trigger))
                    count += 1
                }
            }
        }
    }

    /* 앱이 앞에 떠 있어도 배너로 표시 */
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }

    /* ── JS → 앱 메시지 ── */
    func userContentController(_ userContentController: WKUserContentController,
                               didReceive message: WKScriptMessage) {
        switch message.name {
        case "save":
            if let s = message.body as? String {
                try? s.data(using: .utf8)?.write(to: dataFile, options: .atomic)
                scheduleRoutineNotifications(json: s)
            }
        case "ui":
            guard let s = message.body as? String,
                  let d = s.data(using: .utf8),
                  let obj = try? JSONSerialization.jsonObject(with: d) as? [String: Any],
                  let type = obj["type"] as? String else { return }
            let on = obj["on"] as? Bool ?? false
            if type == "alwaysOnTop" {
                pinned = on
                window.level = (pinned || mini) ? .floating : .normal
            } else if type == "miniMode" {
                pinned = obj["pinned"] as? Bool ?? pinned
                setMini(on)
            } else if type == "flash" {
                // 타이머 종료 등: Dock 아이콘 튀기기 + 소리
                NSApp.requestUserAttention(.criticalRequest)
                NSSound(named: "Glass")?.play()
            }
        default:
            break
        }
    }

    /* ── 미니 타이머 모드: 작은 창으로 줄이고 항상 위에 ── */
    func setMini(_ on: Bool) {
        guard on != mini else { return }
        mini = on
        if on {
            normalFrame = window.frame
            window.minSize = NSSize(width: 300, height: 380)
            let target = NSRect(x: window.frame.maxX - 360, y: window.frame.maxY - 520, width: 360, height: 520)
            window.setFrame(target, display: true, animate: true)
            window.level = .floating
        } else {
            window.minSize = normalMinSize
            if let f = normalFrame { window.setFrame(f, display: true, animate: true) }
            window.level = pinned ? .floating : .normal
        }
    }

    /* ── 링크는 기본 브라우저로, 파일 다운로드(데이터 내보내기)는 저장 패널로 ── */
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        if navigationAction.shouldPerformDownload {
            decisionHandler(.download)
            return
        }
        if let url = navigationAction.request.url,
           navigationAction.navigationType == .linkActivated,
           let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https" {
            NSWorkspace.shared.open(url)
            decisionHandler(.cancel)
            return
        }
        decisionHandler(.allow)
    }

    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
                 for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if let url = navigationAction.request.url { NSWorkspace.shared.open(url) }
        return nil
    }

    func webView(_ webView: WKWebView, navigationAction: WKNavigationAction, didBecome download: WKDownload) {
        download.delegate = self
    }

    func webView(_ webView: WKWebView, navigationResponse: WKNavigationResponse, didBecome download: WKDownload) {
        download.delegate = self
    }

    func download(_ download: WKDownload, decideDestinationUsing response: URLResponse,
                  suggestedFilename: String, completionHandler: @escaping (URL?) -> Void) {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = suggestedFilename
        panel.canCreateDirectories = true
        panel.beginSheetModal(for: window) { result in
            guard result == .OK, let url = panel.url else { completionHandler(nil); return }
            try? FileManager.default.removeItem(at: url)
            completionHandler(url)
        }
    }

    /* ── 파일 불러오기(<input type=file>) → 열기 패널 ── */
    func webView(_ webView: WKWebView, runOpenPanelWith parameters: WKOpenPanelParameters,
                 initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping ([URL]?) -> Void) {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = parameters.allowsMultipleSelection
        panel.canChooseDirectories = parameters.allowsDirectories
        panel.canChooseFiles = true
        panel.beginSheetModal(for: window) { result in
            completionHandler(result == .OK ? panel.urls : nil)
        }
    }

    /* ── alert() → 시스템 경고창 ── */
    func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String,
                 initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
        let alert = NSAlert()
        alert.messageText = message
        alert.addButton(withTitle: "확인")
        alert.beginSheetModal(for: window) { _ in completionHandler() }
    }

    func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String,
                 initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (Bool) -> Void) {
        let alert = NSAlert()
        alert.messageText = message
        alert.addButton(withTitle: "확인")
        alert.addButton(withTitle: "취소")
        alert.beginSheetModal(for: window) { response in
            completionHandler(response == .alertFirstButtonReturn)
        }
    }

    /* ── 창 관리: 닫기는 숨기기, Dock 클릭으로 다시 열기 ── */
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        sender.orderOut(nil)
        return false
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
        return true
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
}

func buildMenu() -> NSMenu {
    let main = NSMenu()

    let appItem = NSMenuItem()
    let appMenu = NSMenu()
    appMenu.addItem(withTitle: "\(appName) 정보", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
    appMenu.addItem(.separator())
    appMenu.addItem(withTitle: "\(appName) 숨기기", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
    appMenu.addItem(.separator())
    appMenu.addItem(withTitle: "\(appName) 종료", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
    appItem.submenu = appMenu
    main.addItem(appItem)

    let editItem = NSMenuItem()
    let editMenu = NSMenu(title: "편집")
    editMenu.addItem(withTitle: "실행 취소", action: Selector(("undo:")), keyEquivalent: "z")
    editMenu.addItem(withTitle: "실행 복귀", action: Selector(("redo:")), keyEquivalent: "Z")
    editMenu.addItem(.separator())
    editMenu.addItem(withTitle: "오려두기", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
    editMenu.addItem(withTitle: "복사하기", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
    editMenu.addItem(withTitle: "붙여넣기", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
    editMenu.addItem(withTitle: "전체 선택", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
    editItem.submenu = editMenu
    main.addItem(editItem)

    let viewItem = NSMenuItem()
    let viewMenu = NSMenu(title: "보기")
    viewMenu.addItem(withTitle: "새로고침", action: #selector(WKWebView.reload(_:)), keyEquivalent: "r")
    viewItem.submenu = viewMenu
    main.addItem(viewItem)

    let windowItem = NSMenuItem()
    let windowMenu = NSMenu(title: "윈도우")
    windowMenu.addItem(withTitle: "최소화", action: #selector(NSWindow.miniaturize(_:)), keyEquivalent: "m")
    windowMenu.addItem(withTitle: "닫기", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
    windowItem.submenu = windowMenu
    main.addItem(windowItem)

    return main
}

let app = NSApplication.shared
app.setActivationPolicy(.regular)
app.mainMenu = buildMenu()
let delegate = AppDelegate()
app.delegate = delegate
app.run()
