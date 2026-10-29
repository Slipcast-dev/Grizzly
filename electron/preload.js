const { contextBridge, ipcRenderer, webUtils } = require('electron');

contextBridge.exposeInMainWorld('api', {
  info: () => ipcRenderer.invoke('app:info'),
  setLanguage: (language) => ipcRenderer.invoke('language:set', language),
  newFile: (dir) => ipcRenderer.invoke('dialog:newFile', dir),
  openDialog: () => ipcRenderer.invoke('dialog:open'),
  openFolderDialog: () => ipcRenderer.invoke('dialog:openFolder'),
  scanDir: (dir) => ipcRenderer.invoke('fs:scanDir', dir),
  readFile: (file) => ipcRenderer.invoke('file:read', file),
  writeFile: (file, text, encoding) => ipcRenderer.invoke('file:write', file, text, encoding),
  saveAs: (name, text, encoding, dir) => ipcRenderer.invoke('dialog:saveAs', name, text, encoding, dir),
  confirmSave: (name) => ipcRenderer.invoke('dialog:confirmSave', name),
  setDirty: (dirty) => ipcRenderer.send('app:dirty', dirty),
  mtimes: (files) => ipcRenderer.invoke('file:mtimes', files),
  reveal: (file) => ipcRenderer.invoke('shell:reveal', file),
  openExternal: (url) => ipcRenderer.invoke('shell:external', url),
  loadLibrary: () => ipcRenderer.invoke('library:load'),
  saveLibrary: (json) => ipcRenderer.invoke('library:save', json),
  pathForFile: (file) => webUtils.getPathForFile(file),
  onMenu: (cb) => ipcRenderer.on('menu', (_e, action) => cb(action)),
  onOpenFiles: (cb) => ipcRenderer.on('open-files', (_e, paths) => cb(paths)),
  ready: () => ipcRenderer.send('renderer:ready'),
});
