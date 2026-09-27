const { contextBridge, ipcRenderer } = require('electron');

contextBridge.exposeInMainWorld('electronAPI', {
  setAlwaysOnTop: (flag) => ipcRenderer.invoke('set-always-on-top', flag),
  setMiniMode: (mini, pinned) => ipcRenderer.invoke('set-mini-mode', { mini, pinned }),
  setDock: (dock, width, pinned) => ipcRenderer.invoke('set-dock', { dock, width, pinned }),
  flashFrame: () => ipcRenderer.send('flash-frame'),
  fetchHolidays: (key, year) => ipcRenderer.invoke('fetch-holidays', { key, year })
});
