"""Phone admission and upload ownership, with no listener, model, account, or real audio."""
import ast
import hmac
import http.server
import io
import json
import queue
import re
import subprocess
import tempfile
import time
import traceback
from collections import deque
from email.message import Message
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import patch

tree = ast.parse(Path(__file__).with_name("dictate.py").read_text(encoding="utf-8"))
phone = next(n for n in tree.body if isinstance(n, ast.FunctionDef) and n.name == "_phone_server")
# The released desktop app must not expose a command listener for recording/cancellation.
assert not any(isinstance(n, ast.Call) and isinstance(n.func, ast.Attribute) and n.func.attr == "listen" for n in ast.walk(tree))

TOKEN = "dummy_phone_token_for_local_checks_only_123456"
handlers, decoded, rewritten, logged = [], [], [], []

class NoRead:
    def read(self, *_): raise AssertionError("rejected requests must not read the body")

def server(address, handler):
    handlers.append(handler)
    return SimpleNamespace(serve_forever=lambda: None)

def run(args, **kwargs):
    if args[1:3] == ["ip", "-4"]: return SimpleNamespace(stdout="192.0.2.1\n")
    upload = Path(args[args.index("-i") + 1])
    assert kwargs["timeout"] == 45
    assert args[args.index("-protocol_whitelist") + 1] == "file,pipe"
    assert set(args[args.index("-format_whitelist") + 1].split(",")) == {"wav", "mp3", "aac", "mov", "flac", "ogg"}
    assert float(args[args.index("-t") + 1]) <= 301
    decoded.append((upload, upload.read_bytes()))
    if upload.read_bytes() == b"decode-failure": raise subprocess.TimeoutExpired(args, 45)
    if upload.read_bytes() == b"too-long": return SimpleNamespace(stdout=bytes(16000 * 4 * 300 + 4))
    return SimpleNamespace(stdout=b"dummy-pcm")

with tempfile.TemporaryDirectory() as root:
    scope = dict(settings=lambda: {"phone_endpoint": True}, read=lambda _: TOKEN, log=lambda *entry: logged.append(entry),
                 re=re, hmac=hmac, time=time, tempfile=tempfile, HERE=Path(root), Path=Path, RATE=16000,
                 shutil=SimpleNamespace(which=lambda name: name), os=SimpleNamespace(path=SimpleNamespace(exists=lambda _: True)),
                 subprocess=SimpleNamespace(run=run, CREATE_NO_WINDOW=0, SubprocessError=subprocess.SubprocessError),
                 np=SimpleNamespace(frombuffer=lambda pcm, _: pcm, float32=object()),
                 transcribe=lambda _: "dummy transcript", polish=lambda raw: rewritten.append(raw) or "finished words")
    exec(compile(ast.Module([phone], []), "dictate.py", "exec"), scope)
    with patch.object(http.server, "HTTPServer", server):
        scope["_phone_server"]()
        assert len(handlers) == 1
        scope["settings"] = lambda: {}
        scope["_phone_server"]()
        scope["settings"] = lambda: {"phone_endpoint": True}
        scope["read"] = lambda _: "short"
        scope["_phone_server"]()
        assert len(handlers) == 1, "off or invalid-token endpoint must stay closed"

    timeouts = []
    connection = SimpleNamespace(settimeout=timeouts.append, makefile=lambda *_: io.BytesIO(), sendall=lambda _: None)
    startup_handler = handlers[0].__new__(handlers[0]); startup_handler.request = connection
    startup_handler.setup()
    assert timeouts == [10], "header and body reads need a connection timeout"
    startup_handler.rfile.close(); startup_handler.wfile.close()

    def request(headers, body=None, path="/dictate"):
        handler = handlers[0].__new__(handlers[0])
        handler.path, handler.headers = path, Message()
        for key, value in headers: handler.headers[key] = value
        handler.rfile = NoRead() if body is None else io.BytesIO(body)
        handler.wfile = io.BytesIO()
        codes = []
        handler.send_error = lambda code, *_: codes.append(code)
        handler.send_response = codes.append
        handler.send_header = lambda *_: None
        handler.end_headers = lambda: None
        handler.do_POST()
        assert len(codes) == 1
        return codes[0], handler.wfile.getvalue()

    auth = [("Authorization", "Bearer " + TOKEN)]
    for headers in ([], [("Authorization", "Bearer wrong")], auth * 2):
        assert request(headers + [("Content-Length", "1")])[0] == 401
    for lengths in ([], [("Content-Length", "-1")], [("Content-Length", "abc")],
                    [("Content-Length", "1")] * 2, [("Content-Length", "1"), ("Transfer-Encoding", "chunked")]):
        assert request(auth + lengths)[0] == 400
    for size in (0, 20 * 1024 * 1024 + 1):
        assert request(auth + [("Content-Length", str(size))])[0] == 413
    assert request(auth + [("Content-Length", "3")], b"a")[0] == 400
    assert request([], path="/other")[0] == 404
    assert not decoded and not rewritten

    for body in (b"first", b"second"):
        assert request(auth + [("Content-Length", str(len(body)))], body) == (200, b"finished words")
        assert decoded[-1][1] == body and not decoded[-1][0].exists()
    assert decoded[0][0] != decoded[1][0], "requests need separate upload storage"
    assert len(rewritten) == 2
    for body, expected in ((b"decode-failure", 500), (b"too-long", 413)):
        assert request(auth + [("Content-Length", str(len(body)))], body)[0] == expected
        assert not decoded[-1][0].exists()
    assert len(rewritten) == 2, "failed or oversized decoding must not reach rewriting"
    assert not list(Path(root).iterdir()), "uploads must be removed after every outcome"
    assert ("phone upload failed:", "TimeoutExpired") in logged

print("PASS: phone authentication, limits, upload cleanup, and desktop listener removal")

# Per-process replies stay in their own queue, and ready messages cannot extend a deadline.
luna = next(n for n in tree.body if isinstance(n, ast.ClassDef) and n.name == "Luna")
receivers, killed = [], []
runtime = dict(subprocess=SimpleNamespace(Popen=lambda *_args, **_kwargs: SimpleNamespace(
                   stdout=iter(['{"id":1}\n', '{"id":2}\n']), pid=7, wait=lambda _: None),
                   run=lambda *_args, **_kwargs: killed.append(True),
                   PIPE=None, DEVNULL=None, CREATE_NO_WINDOW=0),
               threading=SimpleNamespace(Thread=lambda target, **_: SimpleNamespace(start=lambda: receivers.append(target))),
               queue=queue, json=json, shutil=SimpleNamespace(which=lambda _: "codex.cmd"), LEAN=[],
               time=SimpleNamespace(time=lambda: 10), REWRITE_TIMEOUT=20)
exec(compile(ast.Module([luna], []), "dictate.py", "exec"), runtime)
client = runtime["Luna"].__new__(runtime["Luna"])
client.call = lambda *_: None
client.send = lambda *_: None
client.start(); first = client.msgs
client.start(); second = client.msgs
receivers[0](); receivers[1]()
assert first is not second and [first.get_nowait(), first.get_nowait()] == [{"id": 1}, {"id": 2}]
assert client.wait(lambda m: m["id"] == 1, 11) == {"id": 1}
try:
    client.wait(lambda _: True, 10)
    raise AssertionError("ready replies must not bypass an expired deadline")
except queue.Empty: pass
assert killed == [True] and second.get_nowait() == {"id": 2}
print("PASS: server reply ownership and expired rewrite deadline")

history = next(n for n in tree.body if isinstance(n, ast.FunctionDef) and n.name == "history")
with tempfile.TemporaryDirectory() as root:
    saved = dict(HERE=Path(root), json=json, deque=deque)
    exec(compile(ast.Module([history], []), "dictate.py", "exec"), saved)
    assert saved["history"](15) == []
    valid = {"raw": "recent words", "final": "Recent words."}
    rows = [{"raw": "old words", "final": "Old words."}, {"raw": 7, "final": "invalid"}, None, valid]
    (Path(root) / "history.jsonl").write_text("\n".join(json.dumps(row) for row in rows) + '\n{"raw":', encoding="utf-8")
    assert saved["history"](4) == [valid] and saved["history"](0) == []
print("PASS: incomplete history cannot disable rewriting")

# Exercise the startup guard and fatal handler without a socket, model, or host exception hook.
log_fn = next(n for n in tree.body if isinstance(n, ast.FunctionDef) and n.name == "log")
fatal_hook = next(n for n in tree.body if isinstance(n, ast.Assign) and any(
    isinstance(t, ast.Attribute) and t.attr == "excepthook" for t in n.targets))
mode = next(n for n in tree.body if isinstance(n, ast.Assign) and any(
    isinstance(t, ast.Name) and t.id == "test_mode" for t in n.targets))
guard = next(n for n in tree.body if isinstance(n, ast.If) and isinstance(n.test, ast.UnaryOp)
             and isinstance(n.test.operand, ast.Name) and n.test.operand.id == "test_mode")
model = next(n for n in tree.body if isinstance(n, ast.Assign) and any(
    isinstance(t, ast.Name) and t.id == "whisper" for t in n.targets))
assert guard.lineno < model.lineno, "duplicate startup must be rejected before model loading"
bound = []
boot = dict(sys=SimpleNamespace(argv=["dictate.py"]), LOG=io.StringIO(), traceback=traceback,
            time=SimpleNamespace(strftime=lambda _: "00:00:00"),
            socket=SimpleNamespace(socket=lambda: SimpleNamespace(bind=bound.append)))
exec(compile(ast.Module([log_fn, fatal_hook, mode, guard], []), "dictate.py", "exec"), boot)
assert bound == [("127.0.0.1", 47613)]
boot["sys"].excepthook(RuntimeError, RuntimeError("dummy startup failure"), None)
assert "fatal:" in boot["LOG"].getvalue() and "dummy startup failure" in boot["LOG"].getvalue()
boot["sys"].argv = ["dictate.py", "--test", "dummy.wav"]
exec(compile(ast.Module([mode, guard], []), "dictate.py", "exec"), boot)
assert len(bound) == 1, "diagnostic mode must not claim the desktop instance"
print("PASS: startup errors are logged and duplicate startup is guarded")
