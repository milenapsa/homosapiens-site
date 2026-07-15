#!/usr/bin/env python3
from __future__ import annotations

import re
import sys
from html.parser import HTMLParser
from pathlib import Path
from urllib.parse import urlparse

ROOT = Path(__file__).resolve().parents[1]
SITE = ROOT / "site"
PAGES = [SITE / "index.html", SITE / "admin.html"]
ASSETS = [SITE / "assets" / "portal.css", SITE / "assets" / "portal.js", SITE / "assets" / "admin.js"]

SECRET_PATTERNS = {
    "github_token": re.compile(r"\b(?:ghp|gho|ghu|ghs|ghr)_[A-Za-z0-9]{20,}\b"),
    "github_pat": re.compile(r"\bgithub_pat_[A-Za-z0-9_]{20,}\b"),
    "aws_access_key": re.compile(r"\bAKIA[0-9A-Z]{16}\b"),
    "private_key": re.compile(r"-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----"),
    "jwt_like": re.compile(r"\beyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\b"),
}

class PageParser(HTMLParser):
    def __init__(self) -> None:
        super().__init__(convert_charrefs=True)
        self.ids = []
        self.labels = []
        self.references = []
        self.buttons_without_type = []
        self.html_lang = ""
        self.viewport = False
        self._button_index = 0

    def handle_starttag(self, tag, attrs):
        values = {key: value or "" for key, value in attrs}
        if tag == "html":
            self.html_lang = values.get("lang", "")
        if tag == "meta" and values.get("name", "").lower() == "viewport":
            self.viewport = bool(values.get("content"))
        if values.get("id"):
            self.ids.append(values["id"])
        if tag == "label" and values.get("for"):
            self.labels.append(values["for"])
        if tag in {"script", "img"} and values.get("src"):
            self.references.append(values["src"])
        if tag == "link" and values.get("href"):
            self.references.append(values["href"])
        if tag == "button":
            self._button_index += 1
            if not values.get("type"):
                self.buttons_without_type.append(values.get("id") or f"button#{self._button_index}")

def local_reference(page, reference):
    parsed = urlparse(reference)
    if parsed.scheme or parsed.netloc or reference.startswith(("#", "data:", "mailto:", "tel:")):
        return None
    return (page.parent / parsed.path).resolve()

def validate_page(page):
    failures = []
    text = page.read_text(encoding="utf-8")
    parser = PageParser()
    parser.feed(text)
    duplicates = sorted({item for item in parser.ids if parser.ids.count(item) > 1})
    if duplicates:
        failures.append(f"{page}: duplicate ids: {', '.join(duplicates)}")
    missing_targets = sorted(set(parser.labels) - set(parser.ids))
    if missing_targets:
        failures.append(f"{page}: labels without target: {', '.join(missing_targets)}")
    if parser.buttons_without_type:
        failures.append(f"{page}: buttons without explicit type: {', '.join(parser.buttons_without_type)}")
    if parser.html_lang.lower() != "pt-br":
        failures.append(f"{page}: html lang must be pt-BR")
    if not parser.viewport:
        failures.append(f"{page}: viewport meta is required")
    if "<main" not in text or 'id="conteudo"' not in text:
        failures.append(f"{page}: accessible main landmark is missing")
    if "skip-link" not in text:
        failures.append(f"{page}: skip link is missing")
    for reference in parser.references:
        target = local_reference(page, reference)
        if target is not None and not target.is_file():
            failures.append(f"{page}: missing referenced asset: {reference}")
    for name, pattern in SECRET_PATTERNS.items():
        if pattern.search(text):
            failures.append(f"{page}: possible {name} committed")
    return failures

def validate_javascript(path):
    text = path.read_text(encoding="utf-8")
    failures = []
    for name, pattern in SECRET_PATTERNS.items():
        if pattern.search(text):
            failures.append(f"{path}: possible {name} committed")
    if path.name == "admin.js":
        checks = {
            "administrative tokens must not use localStorage": "localStorage" not in text,
            "session-scoped storage is required": "sessionStorage" in text,
            "one-time token copy control is missing": "navigator.clipboard.writeText(oneTimeToken)" in text,
            "one-time token memory clearing is missing": "oneTimeToken = null" in text,
            "token revocation flow is missing": "/tokens/${id}/revoke" in text,
            "mandatory password-change flow is missing": "/admin/password" in text,
            "destructive action confirmation is missing": "window.confirm" in text,
        }
        for message, ok in checks.items():
            if not ok:
                failures.append(f"{path}: {message}")
    if "http://" in text:
        failures.append(f"{path}: insecure HTTP endpoint detected")
    return failures

def validate_css(path):
    text = path.read_text(encoding="utf-8")
    failures = []
    if text.count("{") != text.count("}"):
        failures.append(f"{path}: unbalanced CSS braces")
    for required in (":focus-visible", "@media", "prefers-reduced-motion", ".skip-link"):
        if required not in text:
            failures.append(f"{path}: required accessibility/responsive rule missing: {required}")
    return failures

def main():
    failures = []
    for path in [*PAGES, *ASSETS]:
        if not path.is_file():
            failures.append(f"missing required file: {path}")
    if not failures:
        for page in PAGES:
            failures.extend(validate_page(page))
        failures.extend(validate_javascript(SITE / "assets" / "portal.js"))
        failures.extend(validate_javascript(SITE / "assets" / "admin.js"))
        failures.extend(validate_css(SITE / "assets" / "portal.css"))
    if failures:
        print("\n".join(failures), file=sys.stderr)
        return 1
    print("static-site validation: PASS")
    print(f"pages={len(PAGES)} assets={len(ASSETS)}")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
