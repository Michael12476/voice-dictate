const { contextBridge, ipcRenderer } = require('electron');

contextBridge.exposeInMainWorld('api', {
  load: () => ipcRenderer.invoke('load'),
  saveWords: (words) => ipcRenderer.invoke('saveWords', words),
  saveStyle: (style) => ipcRenderer.invoke('saveStyle', style),
  usage: () => ipcRenderer.invoke('usage'),
  setFast: (fast) => ipcRenderer.invoke('setFast', fast),
});
