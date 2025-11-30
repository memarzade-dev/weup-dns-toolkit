import os
import re

root = os.path.dirname(os.path.abspath(__file__))
project_root = os.path.abspath(os.path.join(root, os.pardir))

ansi_re = re.compile(r"\x1b\[[0-9;]*[A-Za-z]")
replacements = {
    "✓": "OK",
    "✗": "X",
    "⚠": "WARN",
    "▸": ">",
    "·": ".",
    "═": "=",
    "─": "-",
    "╔": "+",
    "╚": "+",
    "║": "|",
    "█": "#",
    "🚀": "",
    "🇮🇷": "IR",
    "🌍": "",
    "🔒": "",
    "👨": "",
    "🔓": "",
    "🧪": "",
    "📊": "",
    "📋": "",
    "🔄": "",
    "⬆️": "",
    "⚙️": "",
    "🚪": "",
    "❤️": "love",
    "❤": "love",
}

def sanitize_text(s):
    s = ansi_re.sub("", s)
    s = "".join(replacements.get(ch, ch) for ch in s)
    return s

targets = []
for dirpath, dirnames, filenames in os.walk(project_root):
    for fn in filenames:
        if fn.endswith((".sh", ".md")):
            targets.append(os.path.join(dirpath, fn))

for path in targets:
    try:
        with open(path, "r", encoding="utf-8") as f:
            content = f.read()
        sanitized = sanitize_text(content)
        if sanitized != content:
            with open(path, "w", encoding="utf-8") as f:
                f.write(sanitized)
    except Exception:
        pass
