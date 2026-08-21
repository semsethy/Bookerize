#!/usr/bin/env python3
"""Build the bundled offline dictionary from Princeton WordNet 3.1.

    python3 tool/build_wordnet.py

Downloads WordNet, parses it, and writes assets/dictionary/wordnet.sqlite.
Run this only when the dictionary needs rebuilding — the result is committed so
a fresh clone builds without it.

Choices made here, and why:
  * Multi-word entries ("ice cream") are skipped. You long-press a single word,
    so they could never be looked up, and they are a large slice of WordNet.
  * At most MAX_SENSES senses per lemma per part of speech. WordNet orders
    senses by how often they are the tagged meaning, so the first few are the
    ones a reader actually wants. Phase 5's "what does it mean here?" handles
    genuine ambiguity with context.
  * Examples are stripped from glosses, keeping the definition only.
  * Each sense carries WordNet's tagged frequency (cntlist.rev), which is what
    lets a lookup pick the sense a reader actually meant. Without it, pressing
    "are" returns the noun: "a unit of surface area equal to 100 square metres".
"""

import os
import re
import sqlite3
import sys
import tarfile
import urllib.request

URL = "https://wordnetcode.princeton.edu/wn3.1.dict.tar.gz"
MAX_SENSES = 5

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "dictionary", "wordnet.sqlite")
WORK = os.path.join("/tmp", "wn")
DICT = os.path.join(WORK, "dict")

POS_FILES = {"noun": "n", "verb": "v", "adj": "a", "adv": "r"}
# WordNet writes adjective satellites as 's'; they are adjectives.
NORMALISE_POS = {"n": "n", "v": "v", "a": "a", "s": "a", "r": "r"}

POS_LABEL = {"n": "noun", "v": "verb", "a": "adjective", "r": "adverb"}

# The digit after '%' in a sense key. 5 is an adjective satellite.
SENSE_KEY_POS = {"1": "n", "2": "v", "3": "a", "4": "r", "5": "a"}


def parse_counts():
    """(lemma, pos, sense_number) -> how often this sense was the tagged one."""
    counts = {}
    path = os.path.join(DICT, "cntlist.rev")
    if not os.path.exists(path):
        return counts
    with open(path, encoding="latin-1") as handle:
        for line in handle:
            parts = line.split()
            if len(parts) != 3:
                continue
            sense_key, sense_number, tag_count = parts
            lemma, _, rest = sense_key.partition("%")
            pos = SENSE_KEY_POS.get(rest[:1])
            if not pos:
                continue
            counts[(lemma.lower(), pos, int(sense_number))] = int(tag_count)
    return counts


def ensure_source():
    if os.path.isdir(DICT):
        return
    os.makedirs(WORK, exist_ok=True)
    archive = os.path.join(WORK, "wn31.tar.gz")
    if not os.path.exists(archive):
        print(f"downloading {URL}")
        urllib.request.urlretrieve(URL, archive)
    print("extracting")
    with tarfile.open(archive) as tar:
        tar.extractall(WORK)


def clean_gloss(raw):
    """"a definition; \"an example\"" -> "a definition"."""
    text = raw.strip()
    cut = re.search(r';\s*"', text)
    if cut:
        text = text[: cut.start()]
    return text.strip().rstrip(";").strip()


def parse_data(pos_name):
    """offset -> gloss, for one part of speech."""
    glosses = {}
    path = os.path.join(DICT, f"data.{pos_name}")
    with open(path, encoding="latin-1") as handle:
        for line in handle:
            if line.startswith("  "):
                continue  # licence header
            head, _, gloss = line.partition("|")
            if not gloss:
                continue
            offset = int(head.split(" ", 1)[0])
            glosses[offset] = clean_gloss(gloss)
    return glosses


def parse_index(pos_name):
    """(lemma, [offsets]) in sense order, single words only."""
    path = os.path.join(DICT, f"index.{pos_name}")
    with open(path, encoding="latin-1") as handle:
        for line in handle:
            if line.startswith("  "):
                continue
            parts = line.split()
            if len(parts) < 6:
                continue
            lemma = parts[0]
            if "_" in lemma:
                continue  # multi-word: unreachable from a long-press
            synset_count = int(parts[2])
            pointer_count = int(parts[3])
            offsets_start = 4 + pointer_count + 2
            offsets = [int(o) for o in parts[offsets_start : offsets_start + synset_count]]
            yield lemma, offsets


def parse_exceptions(pos_name):
    """Irregular inflections: "geese" -> "goose"."""
    path = os.path.join(DICT, f"{pos_name}.exc")
    if not os.path.exists(path):
        return
    with open(path, encoding="latin-1") as handle:
        for line in handle:
            parts = line.split()
            if len(parts) >= 2:
                yield parts[0], parts[1]


def build():
    ensure_source()
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    if os.path.exists(OUT):
        os.remove(OUT)

    db = sqlite3.connect(OUT)
    db.executescript(
        """
        PRAGMA journal_mode = OFF;
        PRAGMA synchronous = OFF;

        CREATE TABLE senses (
          lemma   TEXT NOT NULL,
          pos     TEXT NOT NULL,
          rank    INTEGER NOT NULL,
          gloss   TEXT NOT NULL,
          -- How often this sense is the one meant, from WordNet's tagged
          -- corpus. Ranking by this is what stops "are" resolving to a unit
          -- of area instead of the verb "be".
          tag_count INTEGER NOT NULL DEFAULT 0
        );

        CREATE TABLE exceptions (
          inflected TEXT NOT NULL,
          base      TEXT NOT NULL,
          pos       TEXT NOT NULL
        );
        """
    )

    counts = parse_counts()
    print(f"  frequency data: {len(counts):,} tagged senses")

    sense_rows = 0
    for pos_name, pos in POS_FILES.items():
        glosses = parse_data(pos_name)
        batch = []
        for lemma, offsets in parse_index(pos_name):
            for rank, offset in enumerate(offsets[:MAX_SENSES], start=1):
                gloss = glosses.get(offset)
                if gloss:
                    key = (lemma.lower(), pos, rank)
                    batch.append((lemma.lower(), pos, rank, gloss, counts.get(key, 0)))
            if len(batch) >= 20000:
                db.executemany("INSERT INTO senses VALUES (?,?,?,?,?)", batch)
                sense_rows += len(batch)
                batch = []
        if batch:
            db.executemany("INSERT INTO senses VALUES (?,?,?,?,?)", batch)
            sense_rows += len(batch)

        exceptions = [(i, b, pos) for i, b in parse_exceptions(pos_name)]
        db.executemany("INSERT INTO exceptions VALUES (?,?,?)", exceptions)
        print(f"  {POS_LABEL[pos]:10} senses so far: {sense_rows:,}  exceptions: {len(exceptions):,}")

    db.executescript(
        """
        CREATE INDEX idx_senses_lemma ON senses (lemma);
        CREATE INDEX idx_exceptions_inflected ON exceptions (inflected);
        """
    )
    db.commit()
    db.execute("VACUUM")
    db.commit()
    db.close()

    size = os.path.getsize(OUT)
    print(f"\nwrote {OUT}")
    print(f"  {sense_rows:,} senses, {size / 1024 / 1024:.1f} MB")


if __name__ == "__main__":
    sys.exit(build())
