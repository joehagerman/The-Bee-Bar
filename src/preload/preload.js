const { contextBridge, ipcRenderer } = require('electron');

contextBridge.exposeInMainWorld('beeAPI', {
  getConfig: () => ipcRenderer.invoke('get-config'),
  saveConfig: (config) => ipcRenderer.invoke('save-config', config),
  testConnection: (customConfig) => ipcRenderer.invoke('test-connection', customConfig),
  checkLocalProxy: () => ipcRenderer.invoke('check-local-proxy'),
  selectStorageFolder: () => ipcRenderer.invoke('select-storage-folder'),
  startSync: (options) => ipcRenderer.invoke('start-sync', options),
  cancelSync: () => ipcRenderer.invoke('cancel-sync'),
  getLocalData: () => ipcRenderer.invoke('get-local-data'),
  searchApi: (options) => ipcRenderer.invoke('search-api', options),
  getItemFile: (query) => ipcRenderer.invoke('get-item-file', query),
  openFileInSystem: (filePath) => ipcRenderer.invoke('open-file-in-system', filePath),
  revealInFinder: (filePath) => ipcRenderer.invoke('reveal-in-finder', filePath),
  openStorageFolder: () => ipcRenderer.invoke('open-storage-folder'),
  exportZip: () => ipcRenderer.invoke('export-zip'),
  loadDemoData: () => ipcRenderer.invoke('load-demo-data'),
  onSyncProgress: (callback) => {
    const handler = (event, progress) => callback(progress);
    ipcRenderer.on('sync-progress', handler);
    return () => ipcRenderer.removeListener('sync-progress', handler);
  }
});
