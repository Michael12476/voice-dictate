"""Recovery-flow regression without microphone, model calls, GUI, or clipboard writes."""
import ast
import queue
import threading
from pathlib import Path
from types import SimpleNamespace

source = ast.parse(Path(__file__).with_name("dictate.py").read_text(encoding="utf-8"))
functions = [n for n in source.body if isinstance(n, ast.FunctionDef) and n.name in ("show", "finish", "toggle", "frame")]
foreground, pasted = [100], []
buttons = set()
recording, jobs, events = threading.Event(), queue.Queue(), queue.SimpleQueue()
ui = SimpleNamespace(state="hide", msg="", tick=lambda _: None)
def set_ui(state, msg=""): ui.state, ui.msg = state, msg
ui.set = set_ui
final = "The complete polished dictation."
scope = dict(
    user32=SimpleNamespace(GetForegroundWindow=lambda: foreground[0], GetAsyncKeyState=lambda vk: 0x8000 if vk in buttons else 0),
    recording=recording, jobs=jobs, events=events, ui=ui, session=[0], delivery=[None], level=[0],
    chunks=[], speech_at=[None], RATE=16000, audio_so_far=lambda: bytes(16000),
    threading=SimpleNamespace(Thread=lambda **kwargs: SimpleNamespace(start=lambda: None)),
    live=lambda _: None, transcribe=lambda _: "raw words", polish=lambda _: final,
    paste=pasted.append, log=lambda *args: None,
    time=SimpleNamespace(time=lambda: 0, sleep=lambda _: None),
)
exec(compile(ast.Module(functions, []), "dictate.py", "exec"), scope)

# Switching or closing the destination while recording must not redirect the paste.
scope["toggle"]()
foreground[0] = 200
scope["toggle"]()
scope["finish"](jobs.get_nowait())
assert pasted == [], "a changed destination must not receive the dictation"
assert (ui.state, ui.msg) == ("copy", final), "interrupted dictation must remain recoverable"

# Normal delivery still auto-pastes and hides, per the user's preference.
scope["toggle"](); scope["toggle"]()
scope["finish"](jobs.get_nowait())
assert pasted == [final], "normal dictation should still auto-paste"
assert ui.state == "hide", "uninterrupted dictation should not leave a Copy pill"

# Returning to the original app must not erase a detected window switch.
scope["toggle"]()
foreground[0] = 300
scope["frame"]()
foreground[0] = 200
scope["toggle"]()
scope["finish"](jobs.get_nowait())
assert pasted == [final] and (ui.state, ui.msg) == ("copy", final)

# A click within the same app is also an interruption, including during polishing.
for while_recording in (True, False):
    scope["toggle"]()
    if not while_recording: scope["toggle"]()
    buttons.add(1)
    scope["frame"]()
    buttons.clear()
    if while_recording: scope["toggle"]()
    scope["finish"](jobs.get_nowait())
    assert pasted == [final] and (ui.state, ui.msg) == ("copy", final)

# Clicks after Ctrl+V has been delivered must not produce a false recovery pill.
scope["toggle"]()
scope["toggle"]()
def paste_then_click(text):
    pasted.append(text)
    buttons.add(1); scope["frame"](); buttons.clear()
scope["paste"] = paste_then_click
scope["finish"](jobs.get_nowait())
assert pasted == [final, final] and ui.state == "hide"

def fail_paste(_): raise RuntimeError("clipboard unavailable")
scope["paste"] = fail_paste
scope["toggle"](); scope["toggle"]()
scope["finish"](jobs.get_nowait())
assert (ui.state, ui.msg) == ("copy", final), "paste errors must keep the polished transcript"

# The FIFO worker still delivers A while B records, without replacing B's live UI.
scope["toggle"](); scope["toggle"]()
older = jobs.get_nowait()
scope["toggle"]()
scope["paste"] = pasted.append
scope["polish"] = lambda _: "Older dictation."
scope["finish"](older)
assert ui.state == "listening", "older completion must not replace the current live UI"
assert pasted[-1] == "Older dictation.", "starting B must not discard A's successful delivery"
scope["toggle"]()
scope["polish"] = lambda _: "Newer dictation."
scope["finish"](jobs.get_nowait())
assert pasted[-1] == "Newer dictation." and ui.state == "hide"
print("PASS: window switches, user clicks, normal delivery, paste errors, and newer-session recovery")
