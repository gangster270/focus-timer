const { app, BrowserWindow, ipcMain, screen } = require('electron');
const path = require('path');

let win = null;
const NORMAL = { width: 540, height: 860 };
const MINI = { width: 300, height: 400 };
let savedState = null; /* 미니모드 진입 전 창 상태 */

function createWindow() {
  /* 모니터 작업영역에 맞춰 최대한 넓게 (주간 7칸이 다 보이도록) */
  const wa = screen.getPrimaryDisplay().workAreaSize;
  win = new BrowserWindow({
    width: Math.min(wa.width, 2200),
    height: Math.min(wa.height, 1400),
    minWidth: 300,
    minHeight: 400,
    autoHideMenuBar: true,
    backgroundColor: '#f4f2ed',
    title: 'Focus Timer',
    webPreferences: {
      preload: path.join(__dirname, 'preload.js'),
      contextIsolation: true,
      nodeIntegration: false
    }
  });
  win.maximize();
  win.loadFile('index.html');
}

app.whenReady().then(createWindow);

app.on('window-all-closed', () => {
  if (process.platform !== 'darwin') app.quit();
});

app.on('activate', () => {
  if (BrowserWindow.getAllWindows().length === 0) createWindow();
});

ipcMain.handle('set-always-on-top', (_e, flag) => {
  win.setAlwaysOnTop(!!flag, 'screen-saver');
  return win.isAlwaysOnTop();
});

ipcMain.handle('set-mini-mode', (_e, { mini, pinned }) => {
  if (mini) {
    savedState = { bounds: win.getBounds(), maximized: win.isMaximized() };
    if (win.isMaximized()) win.unmaximize();
    win.setAlwaysOnTop(true, 'screen-saver');
    win.setSize(MINI.width, MINI.height);
  } else {
    if (savedState) {
      win.setBounds(savedState.bounds);
      if (savedState.maximized) win.maximize();
      savedState = null;
    } else {
      win.setSize(NORMAL.width, NORMAL.height);
    }
    win.setAlwaysOnTop(!!pinned, 'screen-saver');
  }
  return mini;
});

/* 위젯 도킹: 창을 현재 모니터 왼쪽 끝에 세로로 꽉 차게 붙임. 풀면 원래 위치·크기로 복귀 */
let dockState = null;
ipcMain.handle('set-dock', async (_e, { dock, width, pinned }) => {
  if (!win) return false;
  if (dock) {
    if (!dockState) dockState = { bounds: win.getBounds(), maximized: win.isMaximized() };
    if (win.isFullScreen()) win.setFullScreen(false);
    if (win.isMaximized()) {
      win.unmaximize();
      await new Promise(r => setTimeout(r, 80));   /* 복원 애니메이션이 setBounds 를 덮어쓰지 않게 */
    }
    const wa = screen.getDisplayMatching(win.getBounds()).workArea;
    const w = Math.max(300, Math.min(Math.round(width) || 380, Math.round(wa.width / 2)));
    win.setBounds({ x: wa.x, y: wa.y, width: w, height: wa.height });
    win.setAlwaysOnTop(!!pinned, 'screen-saver');
  } else {
    if (dockState) {
      win.setBounds(dockState.bounds);
      if (dockState.maximized) win.maximize();
      dockState = null;
    } else {
      win.maximize();   /* 도킹 상태로 앱을 다시 켠 경우: 처음 켤 때처럼 크게 */
    }
    win.setAlwaysOnTop(!!pinned, 'screen-saver');
  }
  return dock;
});

ipcMain.on('flash-frame', () => {
  if (!win) return;
  /* macOS는 작업표시줄 깜빡임이 없어 Dock 아이콘 튀기기로 대체 */
  if (process.platform === 'darwin') {
    if (app.dock && app.dock.bounce) app.dock.bounce('critical');
    return;
  }
  win.flashFrame(true);
  setTimeout(() => win && win.flashFrame(false), 5000);
});

/* 공공데이터포털(한국천문연구원 특일 정보) 공휴일 조회 — CORS 없는 main 프로세스에서 대신 호출 */
ipcMain.handle('fetch-holidays', async (_e, { key, year }) => {
  const sk = key.includes('%') ? key : encodeURIComponent(key);
  const url = 'https://apis.data.go.kr/B090041/openapi/service/SpcdeInfoService/getRestDeInfo'
    + `?serviceKey=${sk}&solYear=${year}&numOfRows=100&_type=json`;
  try {
    const r = await fetch(url);
    const text = await r.text();
    if (!r.ok) {
      // 게이트웨이 오류(401 등)도 본문에 원인이 담겨 있음
      const m = text.match(/<returnAuthMsg>([^<]+)<\/returnAuthMsg>/) || text.match(/"returnAuthMsg"\s*:\s*"([^"]+)"/);
      let msg = m ? m[1] : '';
      if (/NOT_REGISTERED/i.test(msg) || r.status === 401)
        msg += (msg ? ' — ' : '') + '방금 발급한 키는 활성화까지 최대 1시간 걸릴 수 있어요. 잠시 후 다시 시도하세요.';
      return { ok: false, error: 'HTTP ' + r.status + (msg ? ' · ' + msg : '') };
    }
    let j;
    try { j = JSON.parse(text); } catch (err) {
      // 키 오류 등은 XML로 응답됨
      const m = text.match(/<returnAuthMsg>([^<]+)<\/returnAuthMsg>/);
      return { ok: false, error: m ? m[1] : text.slice(0, 200) };
    }
    const header = j && j.response && j.response.header;
    if (!header || header.resultCode !== '00')
      return { ok: false, error: header ? header.resultMsg : '알 수 없는 응답' };
    const items = j.response.body && j.response.body.items && j.response.body.items.item;
    const arr = !items ? [] : Array.isArray(items) ? items : [items];
    const holidays = {};
    arr.forEach(it => {
      if (it.isHoliday !== 'Y') return;
      const s = String(it.locdate);
      holidays[s.slice(0, 4) + '-' + s.slice(4, 6) + '-' + s.slice(6, 8)] = it.dateName;
    });
    return { ok: true, year, holidays };
  } catch (err) {
    return { ok: false, error: '네트워크 오류: ' + String(err && err.message || err) };
  }
});
