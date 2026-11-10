#!/usr/bin/env python3
# Copyright (C) 2026 Reuben Horner <reubarb.scons@gmail.com>
# SPDX-License-Identifier: BSD-3-Clause
"""asteroid-pseudo-locale: a long-text pseudo catalog from Qt .ts files.

Stock Wear OS tests its screens with the en-XA pseudo-locale (accented
letters, text about 40 % longer, wrapped in [ ]; Settings
SupportedLocales.java:39, SystemLocales.java:52). This writes the same kind
of catalog for an AsteroidOS app, so its screens can be checked for clipped
or overflowing text at the largest font size:

  asteroid-pseudo-locale in.ts [more.ts...] -o app.en_XA.ts
  lrelease -idbased app.en_XA.ts -qm app.en_XA.qm
  asteroid-pseudo-locale --json in.ts > strings.json   # {id: pseudo text}

The text of each message is its English source (the //% text lupdate puts
in <source>; for an id with no source, the first translation found). Qt
placeholders (%1, %L1, %n, %%), HTML tags and entities are kept as they are.
"""

import argparse
import json
import re
import sys
import xml.etree.ElementTree as ET

ACCENTS = dict(zip(
    "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ",
    "åƀçđéƒĝĥîĵķļɱñöþǫŕšţûṽŵẋýžÅƁÇĐÉƑĜĤÎĴĶĻṀÑÖÞǪŔŠŢÛṼŴẊÝŽ"))
WORDS = "one two three four five six seven eight nine ten eleven twelve".split()
# kept as they are: Qt arguments, HTML tags, entities
KEEP = re.compile(r"%L?\d+|%n|%%|<[^>]*>|&[#a-zA-Z0-9]+;")
EXPANSION = 1.4


def pseudo(text):
    """Accented, at least 40 % longer, in brackets."""
    if not text:
        return text
    out = []
    pos = 0
    for m in KEEP.finditer(text):
        out.append("".join(ACCENTS.get(c, c) for c in text[pos:m.start()]))
        out.append(m.group(0))
        pos = m.end()
    out.append("".join(ACCENTS.get(c, c) for c in text[pos:]))
    body = "".join(out)
    target = int(len(text) * EXPANSION + 0.999)
    pad = []
    i = 0
    while len(body) + len(" ".join(pad)) + (1 if pad else 0) < target:
        pad.append(WORDS[i % len(WORDS)])
        i += 1
    if pad:
        body += " " + " ".join(pad)
    return "[" + body + "]"


def read_messages(paths):
    """{id: English text} in file order; ids from id= or the source."""
    msgs = {}
    for path in paths:
        root = ET.parse(path).getroot()
        for m in root.iter("message"):
            mid = m.get("id")
            src = m.findtext("source") or ""
            key = mid or src
            if not key:
                continue
            if key in msgs and msgs[key][0]:
                continue
            text = src
            if not text:
                tr = m.find("translation")
                if tr is not None:
                    forms = tr.findall("numerusform")
                    text = forms[0].text if forms else (tr.text or "")
            msgs[key] = (text or "", m.get("numerus") == "yes", mid is not None)
    return msgs


def write_ts(msgs, out):
    ts = ET.Element("TS", version="2.1", language="en_XA", sourcelanguage="en")
    ctx = ET.SubElement(ts, "context")
    ET.SubElement(ctx, "name").text = ""
    for key, (text, numerus, has_id) in msgs.items():
        m = ET.SubElement(ctx, "message")
        if has_id:
            m.set("id", key)
        if numerus:
            m.set("numerus", "yes")
        ET.SubElement(m, "source").text = text if has_id else key
        tr = ET.SubElement(m, "translation")
        if numerus:
            for _ in range(2):
                ET.SubElement(tr, "numerusform").text = pseudo(text)
        else:
            tr.text = pseudo(text)
    ET.indent(ts)
    out.write('<?xml version="1.0" encoding="utf-8"?>\n<!DOCTYPE TS>\n')
    out.write(ET.tostring(ts, encoding="unicode"))
    out.write("\n")


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("ts", nargs="+", help="Qt .ts files (English sources)")
    ap.add_argument("-o", "--output", help="the en_XA .ts to write (default stdout)")
    ap.add_argument("--json", action="store_true", help="write {id: pseudo text} as JSON")
    a = ap.parse_args()
    msgs = read_messages(a.ts)
    out = open(a.output, "w", encoding="utf-8") if a.output else sys.stdout
    if a.json:
        json.dump({k: pseudo(v[0]) for k, v in msgs.items() if v[0]}, out, ensure_ascii=False, indent=1)
        out.write("\n")
    else:
        write_ts(msgs, out)
    return 0


if __name__ == "__main__":
    sys.exit(main())
