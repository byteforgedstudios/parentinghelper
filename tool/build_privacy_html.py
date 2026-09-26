"""Builds the Parenting Helper privacy policy web page from
assets/legal/privacy_policy.md.

The app shows the Markdown file in-app; this script turns the same text into
the page published at
https://byteforgedstudios.github.io/parentinghelper/privacy.html, so the two
never drift apart. The page uses the ByteForged Studios site's header and
stylesheet. The site's root privacy.html is the studio-wide policy used by
other apps; don't overwrite it.

Run from the project root after editing the policy:

    python tool/build_privacy_html.py
    python tool/build_privacy_html.py --out C:/work/byteforgedstudios.github.io/parentinghelper/privacy.html
"""

import argparse
import html
import re
from pathlib import Path

SRC = Path("assets/legal/privacy_policy.md")
DEFAULT_OUT = Path("docs/privacy.html")


def inline(text: str) -> str:
    text = html.escape(text)
    text = re.sub(r"\*\*(.+?)\*\*", r"<strong>\1</strong>", text)
    text = re.sub(r"(https?://[^\s)]+)", r'<a href="\1">\1</a>', text)
    return re.sub(
        r"([\w.+-]+@[\w-]+\.[\w.]+)", r'<a href="mailto:\1">\1</a>', text
    )


def render(markdown: str) -> tuple[str, str, str]:
    """Returns (title, hero paragraphs, body sections)."""
    title, hero, sections = "Privacy Policy", [], []
    current: list[str] | None = None  # open <section>, None = still in hero

    for block in re.split(r"\n\s*\n", markdown.strip()):
        lines = block.strip().splitlines()
        first = lines[0]
        if first.startswith("# "):
            title = first[2:]
            continue
        if first.startswith("## "):
            current = [f"<h2>{inline(first[3:])}</h2>"]
            sections.append(current)
            continue
        if all(l.startswith("- ") for l in lines):
            items = "".join(f"<li>{inline(l[2:])}</li>" for l in lines)
            part = f"<ul>{items}</ul>"
        else:
            part = f"<p>{inline(' '.join(lines))}</p>"
        (hero if current is None else current).append(part)

    body = "\n".join(
        "  <section>\n    " + "\n    ".join(s) + "\n  </section>" for s in sections
    )
    return title, "\n    ".join(hero), body


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT)
    out = parser.parse_args().out

    title, hero, body = render(SRC.read_text(encoding="utf-8"))
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(
        f"""<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>{html.escape(title)} – ByteForged Studios</title>
  <link rel="stylesheet" href="../style.css" />
  <style>
    section a {{ color: #FBD160; }}
    section li {{ margin-bottom: 6px; line-height: 1.5em; }}
    section p {{ line-height: 1.5em; }}
  </style>
</head>
<body>
  <header>
    <div class="logo">ByteForged Studios</div>
    <nav>
      <a href="../index.html">Home</a>
      <a href="privacy.html">Parenting Helper Privacy</a>
    </nav>
  </header>

  <section id="hero">
    <h1>{inline(title)}</h1>
    {hero}
  </section>

{body}

  <footer>
    &copy; 2026 ByteForged Studios. All rights reserved.
  </footer>
</body>
</html>
""",
        encoding="utf-8",
    )
    print(f"Wrote {out}")


if __name__ == "__main__":
    main()
