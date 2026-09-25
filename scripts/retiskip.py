#!/usr/bin/env python3
"""
retiskip.py - RetiSkip: HF band conditions for NomadNet pages.

Pulls solar data and calculated HF band conditions (Good / Fair / Poor, day
and night) from the N0NBH solar feed at hamqsl.com, caches it, and returns it
as a Micron block or a single line of text.

Uses only the Python standard library.

Run directly:   ./retiskip.py            (Micron block)
                ./retiskip.py --line     (single line)
                ./retiskip.py --debug    (show fetch timing)
Or import:      from retiskip import get_band_micron, get_band_string
"""

import os

# ============================ CONFIGURATION ============================

FEED_URL = "https://www.hamqsl.com/solarxml.php"

# Identify yourself to the feed operator (email or callsign).
USER_AGENT = "(RetiSkip, you@example.com)"

# The feed only updates every few hours. Please don't poll it more often
# than hourly; 90 minutes of caching keeps things polite and fast.
CACHE_MINUTES = 90
CACHE_FILE = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                          "retiskip_cache.json")

COLOR_RATINGS = True     # color Good/Fair/Poor green/yellow/red in Micron
SHOW_CREDIT = True       # show "Data: N0NBH (hamqsl.com)" under the block
ESCAPE_MICRON = True     # escape backticks so feed text can't break Micron
HTTP_TIMEOUT = 15        # seconds

# =======================================================================

import json
import sys
import time
import urllib.request
import xml.etree.ElementTree as ET
from datetime import datetime

DEBUG = "--debug" in sys.argv

RATING_COLORS = {"good": "`F0f0", "fair": "`Fff0", "poor": "`Ff00"}


# ----------------------------- fetching --------------------------------

def fetch_xml():
    req = urllib.request.Request(FEED_URL, headers={"User-Agent": USER_AGENT})
    start = time.time()
    with urllib.request.urlopen(req, timeout=HTTP_TIMEOUT) as resp:
        data = resp.read()
    if DEBUG:
        print(f"[debug] {time.time() - start:5.2f}s  {FEED_URL}", file=sys.stderr)
    return data


def parse_feed(xml_bytes):
    """Turn the feed's XML into a plain dict (easy to cache as JSON)."""
    root = ET.fromstring(xml_bytes)
    sd = root.find("solardata")
    if sd is None:
        raise ValueError("feed has no <solardata> element")

    def text(tag):
        el = sd.find(tag)
        if el is None or not el.text:
            return None
        value = el.text.strip()
        return value.replace("`", "\\`") if ESCAPE_MICRON else value

    bands = []   # [{"band": "80m-40m", "day": "Fair", "night": "Good"}, ...]
    for el in sd.findall("calculatedconditions/band"):
        name, when = el.get("name"), (el.get("time") or "").lower()
        rating = (el.text or "").strip()
        if not name or when not in ("day", "night"):
            continue
        row = next((b for b in bands if b["band"] == name), None)
        if row is None:
            row = {"band": name, "day": None, "night": None}
            bands.append(row)
        row[when] = rating

    return {
        "updated": text("updated"),
        "sfi": text("solarflux"),
        "ssn": text("sunspots"),
        "a": text("aindex"),
        "k": text("kindex"),
        "xray": text("xray"),
        "geomag": text("calculatedvhfconditions/geomagfield") or text("geomagfield"),
        "noise": text("calculatedvhfconditions/signalnoise") or text("signalnoise"),
        "bands": bands,
    }


# ------------------------------ cache ----------------------------------

def load_cache():
    try:
        with open(CACHE_FILE) as f:
            return json.load(f)
    except (OSError, ValueError):
        return {}


def save_cache(cache):
    try:
        with open(CACHE_FILE, "w") as f:
            json.dump(cache, f)
    except OSError as e:
        print(f"[retiskip] WARNING: cannot write cache file {CACHE_FILE}: {e}",
              file=sys.stderr)


def get_data():
    """Return (data, stale). Raises only if there is no data at all."""
    cache = load_cache()
    fresh = cache.get("time", 0) > time.time() - CACHE_MINUTES * 60
    if cache.get("data") and fresh:
        return cache["data"], False
    try:
        data = parse_feed(fetch_xml())
        save_cache({"time": time.time(), "data": data})
        return data, False
    except Exception:
        if cache.get("data"):
            return cache["data"], True     # serve the last good copy
        raise


# ----------------------------- formatting ------------------------------

def fmt_updated(raw):
    """' 25 Sep 2026 0100 GMT' -> '0100 UTC 25 Sep'; falls back to the raw text."""
    if not raw:
        return "unknown"
    try:
        return datetime.strptime(raw.strip(), "%d %b %Y %H%M GMT").strftime("%H%M UTC %d %b")
    except ValueError:
        return raw.strip()


def v(value):
    return value if value not in (None, "") else "?"


def color(rating, width=0):
    word = v(rating).ljust(width)
    code = RATING_COLORS.get(v(rating).lower()) if COLOR_RATINGS else None
    return f"{code}{word}`f" if code else word


def build_line(d, stale=False):
    line = (f"HF band conditions @ {fmt_updated(d['updated'])}: "
            f"SFI {v(d['sfi'])}, SSN {v(d['ssn'])}, A {v(d['a'])}, K {v(d['k'])}")
    if d.get("bands"):
        day = ", ".join(f"{b['band']} {v(b['day'])}" for b in d["bands"])
        night = ", ".join(f"{b['band']} {v(b['night'])}" for b in d["bands"])
        line += f" | Day: {day} | Night: {night}"
    return line + (" (cached - update failed)" if stale else "")


def build_micron(d, stale=False, show_title=True):
    out = []
    updated = f"`F888updated {fmt_updated(d['updated'])}" + (" (cached)" if stale else "") + "`f"
    out.append(f"`!HF Band Conditions`!  {updated}" if show_title else updated)
    if d.get("bands"):
        w = max(len(b["band"]) for b in d["bands"]) + 3
        out.append(f"`!{'Band'.ljust(w)}{'Day'.ljust(8)}Night`!")
        for b in d["bands"]:
            out.append(b["band"].ljust(w) + color(b["day"], 8) + color(b["night"]))
    out.append("")
    out.append(f"SFI {v(d['sfi'])}  |  SSN {v(d['ssn'])}  |  A {v(d['a'])}  |  "
               f"K {v(d['k'])}  |  X-ray {v(d['xray'])}")
    out.append(f"Geomag field: {v(d['geomag'])}  |  Noise: {v(d['noise'])}")
    if SHOW_CREDIT:
        out.append("`F888Data: N0NBH (hamqsl.com)`f")
    return "\n".join(out)


def get_band_micron(show_title=True):
    try:
        data, stale = get_data()
        return build_micron(data, stale, show_title)
    except Exception as e:
        return f"Band conditions unavailable ({type(e).__name__})"


def get_band_string():
    try:
        return build_line(*get_data())
    except Exception as e:
        return f"Band conditions unavailable ({type(e).__name__})"


if __name__ == "__main__":
    print(get_band_string() if "--line" in sys.argv else get_band_micron())
