#!/usr/bin/env python3
"""Génère la FAQ de la page support du site à partir de la FAQ de l'app.

Source unique : « PatchTime/Support/SupportContent.swift » (thèmes, ordre) et
« PatchTime/Support/Localizable.strings » (textes). Remplace le contenu situé entre
<!-- FAQ:START --> et <!-- FAQ:END --> dans le fichier HTML passé en argument.

Usage : python3 scripts/export_faq.py [site/index.html]
"""
import html
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent / "PatchTime" / "Support"


def load_strings(path):
    text = path.read_text(encoding="utf-8")
    text = re.sub(r"/\*.*?\*/", "", text, flags=re.S)
    pattern = re.compile(r'"((?:[^"\\]|\\.)*)"\s*=\s*"((?:[^"\\]|\\.)*)"\s*;')
    unescape = lambda s: s.replace('\\"', '"').replace("\\n", "\n").replace("\\\\", "\\")
    return {unescape(k): unescape(v) for k, v in pattern.findall(text)}


def load_themes(path):
    text = path.read_text(encoding="utf-8")
    themes = []
    for theme_id, items in re.findall(r'FAQTheme\(id: "(\w+)", itemIDs: \[([^\]]*)\]\)', text):
        themes.append((theme_id, re.findall(r'"(\w+)"', items)))
    return themes


def render(strings, themes):
    out = []
    for theme_id, item_ids in themes:
        out.append(f'      <h3>{html.escape(strings[f"faq.theme.{theme_id}"])}</h3>')
        for item_id in item_ids:
            question = html.escape(strings[f"faq.{item_id}.q"])
            answer = html.escape(strings[f"faq.{item_id}.a"])
            out.append(f'      <details id="{item_id}">\n'
                       f'        <summary>{question}</summary>\n'
                       f'        <p>{answer}</p>\n'
                       f'      </details>')
    return "\n".join(out)


def main():
    target = pathlib.Path(sys.argv[1]) if len(sys.argv) > 1 else ROOT.parent.parent / "site" / "index.html"
    strings = load_strings(ROOT / "Localizable.strings")
    themes = load_themes(ROOT / "SupportContent.swift")
    page = target.read_text(encoding="utf-8")
    new_block = "<!-- FAQ:START -->\n" + render(strings, themes) + "\n      <!-- FAQ:END -->"
    page, count = re.subn(r"<!-- FAQ:START -->.*?<!-- FAQ:END -->", lambda _: new_block, page, flags=re.S)
    if count != 1:
        sys.exit("Marqueurs FAQ:START / FAQ:END introuvables")
    target.write_text(page, encoding="utf-8")
    print(f"{sum(len(i) for _, i in themes)} questions écrites dans {target}")


if __name__ == "__main__":
    main()
