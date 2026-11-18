const { contextBridge, ipcRenderer } = require('electron');

contextBridge.exposeInMainWorld('electronAPI', {
  setAlwaysOnTop: (flag) => ipcRenderer.invoke('set-always-on-top', flag),
  setMiniMode: (mini, pinned) => ipcRenderer.invoke('set-mini-mode', { mini, pinned }),
  setDock: (dock, width, pinned) => ipcRenderer.invoke('set-dock', { dock, width, pinned }),
  flashFrame: () => ipcRenderer.send('flash-frame'),
  fetchHolidays: (key, year) => ipcRenderer.invoke('fetch-holidays', { key, year }),
  /* 화면 확대·축소: dir = 1(확대) / -1(축소) / 0(100%) → 바뀐 배율 */
  zoom: (dir) => ipcRenderer.invoke('zoom', dir),
  getZoom: () => ipcRenderer.invoke('get-zoom'),
  onZoom: (cb) => ipcRenderer.on('zoom-changed', (_e, f) => cb(f))
});
