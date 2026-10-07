r"""Run with .venv\Scripts\python.exe test_topmost.py on Windows."""
import ast
import ctypes
import ctypes.wintypes as wt
from pathlib import Path

from PySide6.QtCore import Qt
from PySide6.QtWidgets import QApplication, QWidget

# Read the actual binding without starting Whisper, recording, or the hotkey.
source = ast.parse(Path(__file__).with_name("dictate.py").read_text(encoding="utf-8"))
bindings = [node for node in source.body if isinstance(node, ast.Assign)
            and (ast.unparse(node.targets[0]) == "user32"
                 or ast.unparse(node.targets[0]).startswith("user32.SetWindowPos."))]
exec(compile(ast.Module(body=bindings, type_ignores=[]), "dictate.py", "exec"))

app = QApplication([])
window = QWidget(None, Qt.Tool | Qt.WindowDoesNotAcceptFocus)
window.setAttribute(Qt.WA_ShowWithoutActivating)
window.setGeometry(-10000, -10000, 10, 10)
window.show()
try:
    foreground = user32.GetForegroundWindow()
    assert user32.SetWindowPos(int(window.winId()), -1, 0, 0, 0, 0, 0x13), "HWND_TOPMOST call failed"
    assert user32.GetWindowLongW(int(window.winId()), -20) & 0x8, "Window did not become topmost"
    assert user32.GetForegroundWindow() == foreground, "Overlay stole focus"
finally:
    window.close()
print("PASS: topmost call succeeds without taking focus")
