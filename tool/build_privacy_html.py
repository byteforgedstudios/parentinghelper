"""Builds docs/privacy.html from assets/legal/privacy_policy.md.

The app shows the Markdown file in-app; this script turns the same text into
the page published at https://byteforgedstudios.github.io/privacy.html, so the
two never drift apart. Run from the project root after editing the policy:

    python tool/build_privacy_html.py
"""

import html
import re
from pathlib import Path

SRC = Path("assets/legal/privacy_policy.md")
OUT = Path("docs/privacy.html")


def inline(text: str) -> str:
    text = html.escape(text)
    text = re.sub(r"\*\*(.+?)\*\*", r"<strong>\1</strong>", text)
    text = re.sub(r"(https?://[^\s)]+)", r'<a href="\1">\1</a>', text)
    return re.sub(
        r"([\w.+-]+@[\w-]+\.[\w.]+)", r'<a href="mailto:\1">\1</a>', text
    )


def render(markdown: str) -> tuple[str, str]:
    title, parts = "Privacy Policy", []
    for block in re.split(r"\n\s*\n", markdown.strip()):
        lines = block.strip().splitlines()
        first = lines[0]
        if first.startswith("# "):
            title = first[2:]
            parts.append(f"<h1>{inline(title)}</h1>")
        elif first.startswith("## "):
            parts.append(f"<h2>{inline(first[3:])}</h2>")
        elif all(l.startswith("- ") for l in lines):
            items = "".join(f"<li>{inline(l[2:])}</li>" for l in lines)
            parts.append(f"<ul>{items}</ul>")
        else:
            parts.append(f"<p>{inline(' '.join(lines))}</p>")
    return title, "\n".join(parts)


def main() -> None:
    title, body = render(SRC.read_text(encoding="utf-8"))
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(
        f"""<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>{html.escape(title)}</title>
<style>
  :root {{ color-scheme: light dark; --fg: #1d1b20; --bg: #ffffff; --accent: #5e60ce; }}
  @media (prefers-color-scheme: dark) {{ :root {{ --fg: #e6e1e5; --bg: #141218; --accent: #a5a6f6; }} }}
  body {{ margin: 0; background: var(--bg); color: var(--fg);
         font: 16px/1.6 system-ui, -apple-system, "Segoe UI", Roboto, sans-serif; }}
  main {{ max-width: 720px; margin: 0 auto; padding: 32px 16px 64px; }}
  h1 {{ font-size: 1.8rem; line-height: 1.25; }}
  h2 {{ font-size: 1.25rem; margin-top: 2rem; }}
  a {{ color: var(--accent); }}
</style>
</head>
<body>
<main>
{body}
</main>
</body>
</html>
""",
        encoding="utf-8",
    )
    print(f"Wrote {OUT}")


if __name__ == "__main__":
    main()
