// Settings for dictate.py: edits dictionary.txt and style.md next to it, shows recent history.
const { app, BrowserWindow, ipcMain, nativeTheme } = require('electron');
const fs = require('fs');
const path = require('path');
const { pathToFileURL } = require('url');
const page = pathToFileURL(path.join(__dirname, 'index.html')).href;
let win;
const handle = (name, action) => ipcMain.handle(name, (event, ...args) => {
  if (!win || event.sender !== win.webContents || event.senderFrame !== win.webContents.mainFrame || event.senderFrame.url !== page)
    throw new Error('Settings access denied');
  return action(...args);
});

const file = (name) => path.join(__dirname, '..', name);
const read = (name) => { try { return fs.readFileSync(file(name), 'utf8').replace(/^﻿/, ''); } catch { return ''; } };

handle('load', () => ({
  words: read('dictionary.txt').split(/\r?\n/).map((s) => s.trim()).filter((s) => s && !s.startsWith('#')),
  style: read('style.md').trim(),
  history: read('history.jsonl').split(/\r?\n/).filter(Boolean).slice(-15).reverse()
    .map((l) => { try { return JSON.parse(l); } catch { return null; } }).filter(Boolean),
}));
const json = (name, fallback) => { try { return JSON.parse(read(name)); } catch { return fallback; } };
const day = (ms) => new Date(ms).toLocaleDateString('en-CA'); // YYYY-MM-DD, local time

handle('usage', () => {
  const days = [...Array(7)].map((_, i) => day(Date.now() - (6 - i) * 864e5));
  const rows = read('usage.jsonl').split(/\r?\n/).filter(Boolean)
    .map((l) => { try { return JSON.parse(l); } catch { return null; } }).filter(Boolean);
  const account = json('usage-account.json', null);
  const codexByDay = Object.fromEntries((account?.daily || []).map((b) => [b.startDate, b.tokens]));
  return {
    fast: json('settings.json', {}).fast ?? true,
    weekly: account?.rateLimits?.primary || null,
    snapshotAt: account?.ts || null,
    days: days.map((d) => {
      const mine = rows.filter((r) => day(r.ts * 1000) === d);
      return { date: d, dictations: mine.length, tokens: mine.reduce((n, r) => n + r.input + r.output, 0),
        codex: codexByDay[d] ?? null };
    }),
  };
});
handle('setFast', (fast) => {
  if (typeof fast !== 'boolean') throw new Error('Fast must be a boolean');
  let current = {};
  try { current = JSON.parse(fs.readFileSync(file('settings.json'), 'utf8').replace(/^\uFEFF/, '')); }
  catch (error) { if (error.code !== 'ENOENT') throw new Error('settings.json is invalid or unreadable'); }
  if (!current || typeof current !== 'object' || Array.isArray(current)) throw new Error('settings.json must be an object');
  fs.writeFileSync(file('settings.json'), JSON.stringify({ ...current, fast }, null, 2));
});
handle('saveWords', (words) => {
  if (!Array.isArray(words) || words.length > 2000 || words.some((s) => typeof s !== 'string' || s.length > 200 || /[\r\n\0]/.test(s)))
    throw new Error('Use up to 2,000 words or phrases, each at most 200 characters');
  fs.writeFileSync(file('dictionary.txt'), '# One word, name, or phrase per line. Lines starting with # are ignored.\n' + words.join('\n') + '\n');
});
handle('saveStyle', (style) => {
  if (typeof style !== 'string' || style.length > 20000 || style.includes('\0')) throw new Error('Style must be text at most 20,000 characters');
  fs.writeFileSync(file('style.md'), style.trim() + '\n');
});

app.whenReady().then(() => {
  nativeTheme.themeSource = 'dark';
  win = new BrowserWindow({
    width: 560, height: 680, minWidth: 440, minHeight: 520,
    title: 'Dictate', backgroundColor: '#00000000', backgroundMaterial: 'mica', autoHideMenuBar: true,
    titleBarStyle: 'hidden', titleBarOverlay: { color: '#00000000', symbolColor: '#a1a1aa', height: 44 },
    webPreferences: { preload: path.join(__dirname, 'preload.js'), contextIsolation: true, sandbox: true, nodeIntegration: false },
  });
  win.webContents.on('will-navigate', (event) => event.preventDefault());
  win.webContents.setWindowOpenHandler(() => ({ action: 'deny' }));
  win.loadURL(page);
});
app.on('window-all-closed', () => app.quit());
