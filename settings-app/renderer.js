const $ = (id) => document.getElementById(id);
const el = (tag, cls, text) => { const e = document.createElement(tag); if (cls) e.className = cls; if (text != null) e.textContent = text; return e; };
const PRESETS = ['Casual and direct.', 'Professional but friendly.', 'Short sentences.', 'No exclamation marks.',
  'No emoji.', 'Keep my slang and phrasing.', 'Use bullet points when I list things.', 'American spelling.'];
let words = [];
async function saveWords(next) {
  try { await window.api.saveWords(next); words = next; renderWords(); return true; }
  catch { alert('Could not save vocabulary. Use up to 2,000 phrases, each at most 200 characters.'); return false; }
}

// Tabs with a sliding highlight
function moveSlider(btn) {
  $('slider').style.left = btn.offsetLeft + 'px';
  $('slider').style.width = btn.offsetWidth + 'px';
}
document.querySelectorAll('nav button').forEach((b) => b.onclick = () => {
  document.querySelectorAll('nav button, section').forEach((x) => x.classList.remove('on'));
  b.classList.add('on'); $(b.dataset.tab).classList.add('on'); moveSlider(b);
});
requestAnimationFrame(() => moveSlider(document.querySelector('nav button.on')));
addEventListener('resize', () => moveSlider(document.querySelector('nav button.on')));

// Words
function renderWords() {
  $('wordCount').textContent = words.length || '';
  if (!words.length) {
    const empty = el('div', 'empty'); empty.append(el('div', null, '✦'), 'No words yet. Add names or jargon it gets wrong.');
    return $('chips').replaceChildren(empty);
  }
  $('chips').replaceChildren(...words.map((w) => {
    const chip = el('span', 'chip', w);
    const x = el('button'); x.title = 'Remove';
    x.innerHTML = '<svg width="11" height="11" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="3" stroke-linecap="round"><path d="M6 6l12 12M18 6L6 18"/></svg>';
    x.onclick = () => {
      chip.classList.add('out');
      setTimeout(() => saveWords(words.filter((y) => y !== w)), 160);
    };
    chip.append(x);
    return chip;
  }));
}
$('newWord').maxLength = 200;
$('addForm').onsubmit = async (e) => {
  e.preventDefault();
  const w = $('newWord').value.trim();
  if (w && !words.some((x) => x.toLowerCase() === w.toLowerCase()) && !await saveWords([...words, w])) return;
  $('newWord').value = '';
};

// Style (autosaves)
let timer;
$('styleBox').maxLength = 20000;
function styleChanged() {
  const s = $('styleBox').value;
  $('chars').textContent = s.trim() ? `${s.trim().split(/\s+/).length} words` : '';
  $('saved').textContent = 'Saving…'; $('saved').classList.add('busy');
  clearTimeout(timer);
  timer = setTimeout(async () => {
    try { await window.api.saveStyle(s); $('saved').textContent = 'Saved'; }
    catch { $('saved').textContent = 'Could not save. Limit: 20,000 characters.'; }
    $('saved').classList.remove('busy');
  }, 400);
}
$('styleBox').oninput = styleChanged;
$('presets').replaceChildren(...PRESETS.map((p) => {
  const b = el('button', 'preset', '+ ' + p.replace(/\.$/, ''));
  b.onclick = () => {
    const box = $('styleBox');
    if (box.value.includes(p)) return;
    box.value = (box.value.trim() ? box.value.trim() + ' ' : '') + p;
    styleChanged();
  };
  return b;
}));

// Learned
const ago = (ts) => {
  const s = Date.now() / 1000 - ts;
  if (s < 60) return 'just now';
  if (s < 3600) return `${Math.floor(s / 60)} min ago`;
  if (s < 86400) return `${Math.floor(s / 3600)} h ago`;
  return new Date(ts * 1000).toLocaleDateString();
};

// Usage
const short = (n) => n >= 1e6 ? (n / 1e6).toFixed(1) + 'M' : n >= 1e3 ? Math.round(n / 1e3) + 'k' : String(n);
async function renderUsage() {
  const u = await window.api.usage();
  $('fastSwitch').classList.toggle('on', u.fast);
  $('fastSwitch').setAttribute('aria-checked', u.fast);
  const mine = u.days.reduce((n, d) => n + d.tokens, 0);
  const codex = u.days.reduce((n, d) => n + (d.codex || 0), 0);
  $('tDict').textContent = u.days.reduce((n, d) => n + d.dictations, 0);
  $('tTok').textContent = short(mine);
  $('tShare').textContent = codex ? (mine / codex * 100 < 0.1 && mine ? '<0.1%' : (mine / codex * 100).toFixed(1) + '%') : '–';
  if (u.weekly) {
    $('weeklyText').textContent = `${u.weekly.usedPercent}% used`;
    requestAnimationFrame(() => $('weeklyFill').style.width = Math.min(100, u.weekly.usedPercent) + '%');
    $('weeklyNote').textContent = `Resets ${new Date(u.weekly.resetsAt * 1000).toLocaleString([], { weekday: 'short', hour: 'numeric', minute: '2-digit' })}. This includes all your Codex use, not just dictation.`;
  } else {
    $('weeklyNote').textContent = 'Shows up after your next dictation.';
  }
  const max = Math.max(1, ...u.days.map((d) => d.tokens));
  const today = u.days[u.days.length - 1].date;
  $('chart').replaceChildren(...u.days.map((d, i) => {
    const col = el('div', 'col' + (d.date === today ? ' today' : ''));
    const bar = el('div', 'b' + (d.tokens ? '' : ' zero'));
    bar.style.height = Math.max(3, d.tokens / max * 100) + 'px'; bar.style.animationDelay = i * 40 + 'ms';
    bar.title = `${d.dictations} dictations, ${d.tokens.toLocaleString()} tokens`;
    col.append(el('span', 'v', d.tokens ? short(d.tokens) : ''), bar,
      el('span', 'd', new Date(d.date + 'T12:00').toLocaleDateString([], { weekday: 'short' })));
    return col;
  }));
}
$('fastSwitch').onclick = async () => {
  try { await window.api.setFast(!$('fastSwitch').classList.contains('on')); await renderUsage(); }
  catch { alert('Could not save Fast mode. Check settings.json for errors.'); }
};
document.querySelector('[data-tab=usage]').addEventListener('click', renderUsage);
renderUsage();

window.api.load().then((d) => {
  words = d.words; renderWords();
  $('styleBox').value = d.style; $('chars').textContent = d.style ? `${d.style.split(/\s+/).length} words` : '';
  $('histCount').textContent = d.history.length || '';
  if (!d.history.length) {
    const empty = el('div', 'empty'); empty.append(el('div', null, '◌'), 'Nothing yet. Dictate something first.');
    return $('history').replaceChildren(empty);
  }
  $('history').replaceChildren(...d.history.map((h, i) => {
    const item = el('div', 'card item'); item.style.animationDelay = `${i * 30}ms`;
    const meta = el('div', 'meta'); meta.append(el('span', null, 'You said'), el('span', null, ago(h.ts)));
    item.append(meta, el('div', 'raw', h.raw), el('div', 'final', h.final));
    return item;
  }));
});
