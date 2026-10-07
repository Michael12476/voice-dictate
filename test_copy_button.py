"""Copy-button check: loads only the Pill class from dictate.py. Run: .venv/Scripts/python test_copy_button.py"""
import ast, ctypes, ctypes.wintypes as wt, math, sys
from pathlib import Path
import pyperclip
from PySide6.QtCore import QEventLoop, QPoint, QRectF, Qt, QTimer
from PySide6.QtGui import QColor, QFont, QFontMetrics, QGuiApplication, QLinearGradient, QPainter, QPainterPath, QPen
from PySide6.QtWidgets import QApplication, QWidget

src = (Path(__file__).parent / "dictate.py").read_text(encoding="utf-8")
user32 = ctypes.WinDLL("user32")
exec(compile(ast.Module([n for n in ast.parse(src).body if isinstance(n, ast.ClassDef) and n.name == "Pill"], []), "dictate.py", "exec"))
for line in src.splitlines():  # same ctypes signatures as the app
    if line.startswith("user32.") and "Hook" not in line and ("argtypes" in line or "restype" in line): exec(line)
user32.PostMessageW.argtypes = [wt.HWND, wt.UINT, wt.WPARAM, wt.LPARAM]
user32.PostMessageW.restype = wt.BOOL

app = QApplication(sys.argv)
ui = Pill()
ui.move(-10000, -10000)  # exercise native routing without covering the user's work
def clickable(): return not user32.GetWindowLongW(int(ui.winId()), -20) & 0x20  # WS_EX_TRANSPARENT off
def run(ms):
    loop = QEventLoop()
    end = QTimer(); end.setSingleShot(True); end.timeout.connect(loop.quit); end.start(ms)
    t = QTimer(); t.timeout.connect(lambda: ui.tick(0)); t.start(16); loop.exec()

def mouse(message, point, buttons=0):
    # QTest.mouseClick bypasses Qt's Windows input filtering, which hid the original bug.
    scale = ui.devicePixelRatioF()
    x, y = round(point.x() * scale), round(point.y() * scale)
    assert user32.PostMessageW(int(ui.winId()), message, buttons, (y << 16) | (x & 0xffff))
    run(50)

def click(point):
    mouse(0x201, point, 1)  # WM_LBUTTONDOWN, MK_LBUTTON
    mouse(0x202, point)  # WM_LBUTTONUP

ui.set("working", "some raw text"); run(400)
assert not clickable(), "pill must click through while polishing"

text = "Polished text that never got pasted. " * 12 + "Café 🎙️"
ui.set("copy", text); run(700)
ui.grab().save(str(Path(__file__).parent / "test-copy-button.png"))
assert clickable() and not ui.btn.isEmpty()

old = pyperclip.paste()
try:
    foreground = user32.GetForegroundWindow()
    mouse(0x200, ui.btn.center(), 4)  # WM_MOUSEMOVE, MK_SHIFT avoids Qt discarding the first offscreen enter
    assert ui.cursor().shape() == Qt.PointingHandCursor, "native hover must reach the Copy button"
    click(ui.btn.center())
    assert pyperclip.paste() == text and ui.state == "copied", "copy must include text trimmed from the preview"
    assert user32.GetForegroundWindow() == foreground, "copying must not steal focus"
    run(1100)
    assert ui.state == "hide" and not clickable(), "should hide and click through again after copying"

    ui.set("copy", "x"); run(300)
    click(QPoint(int(ui.btn.left()) - 40, int(ui.btn.center().y())))
    assert ui.state == "copy", "clicking the text must not discard the recoverable dictation"
finally:
    if pyperclip.paste() == text: pyperclip.copy(old)
    ui.close()
print("ok")
