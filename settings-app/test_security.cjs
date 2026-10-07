// Exercise the real IPC boundary with a dummy window and in-memory files; no Electron process.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const handlers = new Map();
const writes = [];
let window;
class BrowserWindow {
  constructor(options) {
    this.options = options;
    this.webContents = { mainFrame: { url: '' },
      on: (_, fn) => { this.navigate = fn; }, setWindowOpenHandler: (fn) => { this.open = fn; } };
    window = this;
  }
  loadURL(url) { this.loaded = url; this.webContents.mainFrame.url = url; }
}
const electron = { BrowserWindow, nativeTheme: {}, ipcMain: { handle: (name, fn) => handlers.set(name, fn) },
  app: { whenReady: () => ({ then: (fn) => fn() }), on: () => {} } };
let settingsText;
const disk = { readFileSync: (file) => {
    if (path.basename(file) === 'settings.json' && settingsText !== undefined) return settingsText;
    throw Object.assign(new Error('missing dummy file'), { code: 'ENOENT' });
  },
  writeFileSync: (file, text) => writes.push({ file, text }) };
vm.runInNewContext(fs.readFileSync(path.join(__dirname, 'main.js'), 'utf8'), {
  require: (name) => name === 'electron' ? electron : name === 'fs' ? disk : require(name), __dirname,
});
const good = { sender: window.webContents, senderFrame: window.webContents.mainFrame };
for (const invoke of handlers.values()) {
  for (const bad of [ { ...good, sender: {} }, { ...good, senderFrame: { ...good.senderFrame } } ])
    assert.throws(() => invoke(bad), /Settings access denied/);
  const url = good.senderFrame.url;
  good.senderFrame.url = 'https://example.invalid/';
  assert.throws(() => invoke(good), /Settings access denied/);
  good.senderFrame.url = url;
}
const invoke = (name, value) => handlers.get(name)(good, value);
for (const fast of [null, 'true', 1, {}]) assert.throws(() => invoke('setFast', fast));
for (const words of ['word', [123], ['a\nb'], ['a\0b'], ['x'.repeat(201)], Array(2001).fill('x')])
  assert.throws(() => invoke('saveWords', words));
for (const style of [null, [], 'x'.repeat(20001), 'a\0b']) assert.throws(() => invoke('saveStyle', style));
assert.equal(writes.length, 0, 'denied calls must not write files');
for (const invalid of ['{', '[]', 'null', '']) {
  settingsText = invalid;
  assert.throws(() => invoke('setFast', false));
}
assert.equal(writes.length, 0, 'invalid settings must not be overwritten');
settingsText = '{"codex_model":"dummy-model","phone_endpoint":true,"custom":"caf\\u00e9"}';
invoke('setFast', false);
invoke('saveWords', ['Whisper', '<text stays data>']);
invoke('saveStyle', ' Plain words. ');
assert.deepEqual(writes.map((w) => path.basename(w.file)), ['settings.json', 'dictionary.txt', 'style.md']);
assert.equal(JSON.parse(writes[0].text).fast, false);
assert.equal(JSON.parse(writes[0].text).codex_model, 'dummy-model');
assert.equal(JSON.parse(writes[0].text).phone_endpoint, true);
assert.equal(JSON.parse(writes[0].text).custom, 'café');
assert.equal(new URL(window.loaded).protocol, 'file:');
assert.ok(writes[1].text.includes('<text stays data>'));
assert.equal(writes[2].text, 'Plain words.\n');
assert.equal(window.options.webPreferences.contextIsolation, true);
assert.equal(window.options.webPreferences.sandbox, true);
assert.equal(window.options.webPreferences.nodeIntegration, false);
let prevented = false;
window.navigate({ preventDefault: () => { prevented = true; } });
assert.ok(prevented);
assert.equal(window.open().action, 'deny');
console.log('PASS: settings sender, payloads, preservation, and navigation isolation');
