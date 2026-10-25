const { app, BrowserWindow, ipcMain, shell, dialog } = require('electron');
const path = require('path');
const fs = require('fs');
const BeeSyncEngine = require('./sync-engine');

let mainWindow;
let syncEngine;

const CONFIG_PATH = path.join(app.getPath('home'), '.bee-desktop', 'config.json');

function loadConfig() {
  const defaultDir = path.join(app.getPath('documents'), 'Bee Exports');
  try {
    if (fs.existsSync(CONFIG_PATH)) {
      const data = JSON.parse(fs.readFileSync(CONFIG_PATH, 'utf8'));
      return {
        endpoint: data.endpoint || 'https://api.developer.bee.amazon.dev',
        token: data.token || process.env.BEE_TOKEN || '',
        storageDir: data.storageDir || defaultDir,
        user: data.user || null
      };
    }
  } catch (err) {
    console.error('Failed to read config file:', err);
  }
  return {
    endpoint: 'https://api.developer.bee.amazon.dev',
    token: process.env.BEE_TOKEN || '',
    storageDir: defaultDir,
    user: null
  };
}

function saveConfig(config) {
  try {
    const dir = path.dirname(CONFIG_PATH);
    if (!fs.existsSync(dir)) {
      fs.mkdirSync(dir, { recursive: true });
    }
    fs.writeFileSync(CONFIG_PATH, JSON.stringify(config, null, 2));
  } catch (err) {
    console.error('Failed to save config:', err);
  }
}

function createWindow() {
  const config = loadConfig();
  syncEngine = new BeeSyncEngine(config);

  mainWindow = new BrowserWindow({
    width: 1280,
    height: 850,
    minWidth: 1000,
    minHeight: 650,
    titleBarStyle: 'hiddenInset',
    trafficLightPosition: { x: 18, y: 18 },
    backgroundColor: '#0f1117',
    webPreferences: {
      preload: path.join(__dirname, '..', 'preload', 'preload.js'),
      contextIsolation: true,
      nodeIntegration: false
    }
  });

  mainWindow.loadFile(path.join(__dirname, '..', 'renderer', 'index.html'));

  mainWindow.webContents.setWindowOpenHandler(({ url }) => {
    shell.openExternal(url);
    return { action: 'deny' };
  });

  mainWindow.on('closed', () => {
    mainWindow = null;
  });
}

app.whenReady().then(() => {
  createWindow();

  app.on('activate', () => {
    if (BrowserWindow.getAllWindows().length === 0) {
      createWindow();
    }
  });
});

app.on('window-all-closed', () => {
  if (process.platform !== 'darwin') {
    app.quit();
  }
});

// IPC Handlers

ipcMain.handle('get-config', async () => {
  return loadConfig();
});

ipcMain.handle('save-config', async (event, newConfig) => {
  const current = loadConfig();
  const updated = { ...current, ...newConfig };
  saveConfig(updated);
  if (syncEngine) {
    syncEngine.updateConfig(updated);
  }
  return updated;
});

ipcMain.handle('test-connection', async (event, customConfig) => {
  const current = loadConfig();
  const testCfg = { ...current, ...(customConfig || {}) };
  const tempEngine = new BeeSyncEngine(testCfg);
  const result = await tempEngine.testConnection();
  if (result.success && result.data) {
    current.user = result.data;
    saveConfig(current);
  }
  return result;
});

ipcMain.handle('check-local-proxy', async () => {
  const proxyEngine = new BeeSyncEngine({
    endpoint: 'http://127.0.0.1:8787',
    token: ''
  });
  return await proxyEngine.testConnection();
});

ipcMain.handle('select-storage-folder', async () => {
  const result = await dialog.showOpenDialog(mainWindow, {
    title: 'Select Destination Folder for Bee Exports',
    properties: ['openDirectory', 'createDirectory']
  });

  if (!result.canceled && result.filePaths.length > 0) {
    const selected = result.filePaths[0];
    const current = loadConfig();
    current.storageDir = selected;
    saveConfig(current);
    if (syncEngine) {
      syncEngine.updateConfig(current);
    }
    return selected;
  }
  return null;
});

ipcMain.handle('start-sync', async (event) => {
  if (!syncEngine) {
    syncEngine = new BeeSyncEngine(loadConfig());
  }

  try {
    const result = await syncEngine.syncAll((progress) => {
      if (mainWindow && !mainWindow.isDestroyed()) {
        mainWindow.webContents.send('sync-progress', progress);
      }
    });
    return result;
  } catch (err) {
    return { success: false, error: err.message };
  }
});

ipcMain.handle('cancel-sync', async () => {
  if (syncEngine) {
    syncEngine.cancelSync();
    return true;
  }
  return false;
});

ipcMain.handle('get-local-data', async () => {
  if (!syncEngine) {
    syncEngine = new BeeSyncEngine(loadConfig());
  }
  return syncEngine.loadLocalData();
});

ipcMain.handle('search-api', async (event, queryOptions) => {
  if (!syncEngine) {
    syncEngine = new BeeSyncEngine(loadConfig());
  }
  try {
    return await syncEngine.searchApi(queryOptions);
  } catch (e) {
    return { error: e.message };
  }
});

ipcMain.handle('get-item-file', async (event, { type, id }) => {
  if (!syncEngine) {
    syncEngine = new BeeSyncEngine(loadConfig());
  }
  return syncEngine.getItemFile(type, id);
});

ipcMain.handle('open-file-in-system', async (event, filePath) => {
  if (fs.existsSync(filePath)) {
    await shell.openPath(filePath);
    return true;
  }
  return false;
});

ipcMain.handle('reveal-in-finder', async (event, filePath) => {
  const target = filePath || syncEngine.storageDir;
  if (fs.existsSync(target)) {
    shell.showItemInFolder(target);
    return true;
  }
  return false;
});

ipcMain.handle('open-storage-folder', async () => {
  const dir = syncEngine.storageDir;
  syncEngine.ensureDirectories();
  await shell.openPath(dir);
  return true;
});

ipcMain.handle('export-zip', async () => {
  const defaultZip = path.join(app.getPath('downloads'), `bee-backup-${new Date().toISOString().slice(0, 10)}.zip`);
  const saveResult = await dialog.showSaveDialog(mainWindow, {
    title: 'Export All Bee Data as ZIP Archive',
    defaultPath: defaultZip,
    filters: [{ name: 'ZIP Archives', extensions: ['zip'] }]
  });

  if (!saveResult.canceled && saveResult.filePath) {
    try {
      const res = await syncEngine.exportZip(saveResult.filePath);
      return { success: true, path: res.path, bytes: res.bytes };
    } catch (e) {
      return { success: false, error: e.message };
    }
  }
  return { success: false, cancelled: true };
});

ipcMain.handle('load-demo-data', async () => {
  if (!syncEngine) {
    syncEngine = new BeeSyncEngine(loadConfig());
  }
  return syncEngine.seedDemoData();
});
