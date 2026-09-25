#!/usr/bin/python3
# retiskip.mu - RetiSkip HF band conditions page for NomadNet.
# The first line must be the full path to your Python (run: which python3).
import os
import sys

SCRIPTS_DIR = os.path.expanduser("~/scripts")
sys.path.insert(0, SCRIPTS_DIR)

try:
    from retiskip import get_band_micron
    conditions = get_band_micron(show_title=False)
except Exception as e:
    conditions = f"Band conditions unavailable ({type(e).__name__})"

print(""">RetiSkip: HF Band Conditions

""" + conditions + """

>>Reading the numbers
`!SFI`! (solar flux): higher is better for the upper bands. Above about 100, 15m through 10m start to open up.
`!SSN`! (sunspot number): follows the 11-year solar cycle. More sunspots generally means better HF.
`!K`! (K index): geomagnetic activity right now. 0-2 is quiet, 3-4 unsettled to active, 5 or more is a storm.
`!A`! (A index): the day's average geomagnetic activity. Below about 10 is quiet.

Ratings are calculated estimates, not guarantees. The best test is still to get on the air and listen.

`[Back to home`:/page/index.mu]""")
