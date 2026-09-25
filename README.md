# RetiSkip

HF band conditions for your NomadNet node. RetiSkip adds a ready-made page showing day and night band ratings, solar flux, sunspots, and geomagnetic activity, refreshed automatically and served from a cache so it loads instantly over the mesh.

Here's roughly what visitors see. In a NomadNet client, the ratings are colored green, yellow, and red:

```
RetiSkip: HF Band Conditions

updated 0100 UTC 25 Sep
Band      Day     Night
80m-40m   Fair    Good
30m-20m   Good    Good
17m-15m   Good    Fair
12m-10m   Fair    Poor

SFI 152  |  SSN 118  |  A 8  |  K 2  |  X-ray B6.1
Geomag field: QUIET  |  Noise: S1-S2
Data: N0NBH (hamqsl.com)

  Reading the numbers
  SFI (solar flux): higher is better for the upper bands...
```

The page ends with a short guide to what SFI, SSN, K, and A mean, for visitors who are new to HF.

## Features

- A complete standalone page at `/page/retiskip.mu`. Install it and link to it; no page editing needed.
- Day and night Good/Fair/Poor ratings for 80m through 10m, plus solar flux, sunspot number, A and K indices, X-ray flux, geomagnetic field, and noise level.
- Fast page loads. A cron job refreshes the data hourly and saves it, so visitors never wait on the internet.
- Fails gracefully. If the data feed is unreachable, the page shows the last good data, or "Band conditions unavailable", and still loads.
- Python standard library only. Nothing to `pip install`, and no API key.
- Can also show band conditions on your other pages, as a block or a single line.

## Requirements

- A NomadNet node, installed and running
- Python 3.9 or newer
- Internet access from the node
- An email address or callsign, sent to the data feed to identify your node

## Install options

There are two ways to install RetiSkip. Both give the same result:

- **Quick install:** run `install.sh`, which asks one question and does everything for you. Best for most people.
- **Manual install:** copy the files and set things up by hand. Use this if you want to see every step before it happens, or if your setup is unusual.

Either way, install as the same user that runs NomadNet. Installing doesn't need `sudo`, though restarting a system-wide NomadNet service afterward may.

## Quick install

Run as the same user that runs NomadNet:

```
git clone <this repo URL>
cd retiskip
./install.sh
```

The installer asks for your email or callsign. To skip the question:

```
CONTACT=you@example.com ./install.sh
```

### What the installer does

1. Checks for Python 3.9+ and your NomadNet pages folder (`~/.nomadnetwork/storage/pages`).
2. Installs `retiskip.py` in `~/scripts` with your contact and full Python path.
3. Installs the page as `retiskip.mu` in your pages folder. If you already have an unrelated page with that name, it's backed up to `~/scripts` first.
4. Runs a test fetch with timing output.
5. Adds a cron job that refreshes the data once an hour (only once, even if you rerun it).

### Installer options

Set any of these before `./install.sh` to change how it runs:

| Option | Default | What it does |
| --- | --- | --- |
| `CONTACT` | asks | Your email or callsign; skips the question |
| `SCRIPTS_DIR` | `~/scripts` | Where `retiskip.py` and its cache go |
| `PAGES_DIR` | `~/.nomadnetwork/storage/pages` | Your NomadNet pages folder |
| `PYTHON` | output of `which python3` | Python to use (3.9 or newer) |

For example:

```
PYTHON=/usr/bin/python3 SCRIPTS_DIR=~/retiskip-files ./install.sh
```

It's safe to run the installer again, for example after updating the repo. It updates the page and script in place and won't add a second cron job.

### Restart NomadNet

NomadNet registers its pages when it starts, so restart it after installing to make sure the new page is picked up. If NomadNet runs as a systemd service:

```
sudo systemctl restart nomadnet
```

Use your own unit name if it's different (check with `systemctl list-units | grep -i nomad`), or `systemctl --user restart nomadnet` for a user service. If you start NomadNet by hand, stop it and start it again.

### Link to it

Visit `/page/retiskip.mu` on your node to check the page, then add a link from your home page or menu:

```
`[Band Conditions`:/page/retiskip.mu]
```

## Manual install

To do the same steps by hand from the repo folder, as the NomadNet user:

1. Copy the script:
   ```
   mkdir -p ~/scripts
   cp scripts/retiskip.py ~/scripts/
   chmod +x ~/scripts/retiskip.py
   ```
2. Edit `~/scripts/retiskip.py` and put your email or callsign in `USER_AGENT`.
3. Find your full Python path. It must be version 3.9 or newer:
   ```
   which python3
   python3 --version
   ```
   NomadNet runs page scripts without your login shell, so put this full path on the first line of `pages/retiskip.mu`, in the form `#!/usr/bin/python3`.
4. Install the page:
   ```
   cp pages/retiskip.mu ~/.nomadnetwork/storage/pages/
   chmod +x ~/.nomadnetwork/storage/pages/retiskip.mu
   ```
5. Test it. You should see a `[debug]` timing line, then the band conditions:
   ```
   ~/scripts/retiskip.py --debug
   ```
6. Add the hourly cron job, using your Python path from step 3. Then confirm it with `crontab -l`:
   ```
   (crontab -l 2>/dev/null; echo "7 * * * * /usr/bin/python3 $HOME/scripts/retiskip.py > /dev/null 2>&1") | crontab -
   ```
7. Restart NomadNet, as described under [Restart NomadNet](#restart-nomadnet).

If you put the script somewhere other than `~/scripts`, also change the `SCRIPTS_DIR` line near the top of `retiskip.mu` to match.

## Files

| Path in repo | Installed to | What it is |
| --- | --- | --- |
| `scripts/retiskip.py` | `~/scripts/` | Fetches the data, caches it, and formats it |
| `pages/retiskip.mu` | `~/.nomadnetwork/storage/pages/` | The band conditions page |

`retiskip_cache.json` is created next to `retiskip.py` on the first run.

## How it works

1. Cron runs `retiskip.py` once an hour. It downloads the N0NBH solar feed from hamqsl.com, which includes calculated day and night conditions for each band group.
2. The script saves the parsed data to `retiskip_cache.json` and reuses it for 90 minutes.
3. When someone opens the page, `retiskip.mu` reads the saved data and prints it as Micron, so the page never waits on the internet.

The feed updates every few hours, so polling hourly keeps the page current without putting extra load on the feed's operator. The cron job runs at 7 minutes past the hour rather than exactly on the hour, to avoid adding to the rush of requests at the top of the hour.

## Show band conditions on other pages

To add the band conditions block to a page that is already a Python script, add this with no leading spaces:

```python
import os
import sys
sys.path.insert(0, os.path.expanduser("~/scripts"))

try:
    from retiskip import get_band_micron
    bands = get_band_micron()
except Exception as e:
    bands = f"Band conditions unavailable ({type(e).__name__})"
print(bands)
```

The `try` block makes sure a problem with band conditions can never stop the rest of the page from loading.

For a single line instead of a block, use `get_band_string()`:

```
HF band conditions @ 0100 UTC 25 Sep: SFI 152, SSN 118, A 8, K 2 | Day: 80m-40m Fair, 30m-20m Good, ... | Night: ...
```

## Configuration

Settings are at the top of `retiskip.py`. The installer sets `USER_AGENT` for you.

| Setting | Default | What it does |
| --- | --- | --- |
| `USER_AGENT` | `"(RetiSkip, you@example.com)"` | Identifies your node to the data feed |
| `CACHE_MINUTES` | `90` | How long saved data is reused |
| `COLOR_RATINGS` | `True` | Colors Good/Fair/Poor green/yellow/red |
| `SHOW_CREDIT` | `True` | Shows the data source under the conditions |
| `HTTP_TIMEOUT` | `15` | Seconds to wait for the feed |

Please keep `CACHE_MINUTES` at 60 or more, and the cron job no more often than hourly. The feed only updates every few hours, so fetching more often adds load without giving you fresher data.

## Troubleshooting

Run the page by hand, the same way NomadNet does. Errors print here but not in the client:

```
~/.nomadnetwork/storage/pages/retiskip.mu
```

To check the data fetch itself, run `~/scripts/retiskip.py --debug`. If you see no `[debug]` line, the data came from the cache; delete `~/scripts/retiskip_cache.json` and run it again.

| Symptom | Fix |
| --- | --- |
| Client says "No content available" | Run the page by hand (above) to see the error |
| Page shows the script's code | `chmod +x ~/.nomadnetwork/storage/pages/retiskip.mu` |
| Page doesn't show up at all | Restart NomadNet (see [Restart NomadNet](#restart-nomadnet)) |
| Page fails after editing on another computer | The file may have Windows line endings; fix with `sed -i 's/\r$//' ~/.nomadnetwork/storage/pages/retiskip.mu` |
| Shows "Band conditions unavailable" | Check that `~/scripts/retiskip.py` exists, and that the first line of `retiskip.mu` is your Python path (`which python3`) |
| `WARNING: cannot write cache file` | Make `~/scripts` writable by the NomadNet user |
| "(cached)" appears after the update time | The feed was unreachable; it clears on the next good update |
| Data never updates | Check `crontab -l` for the RetiSkip job |

## Uninstall

```
crontab -l | grep -v retiskip.py | crontab -
rm ~/.nomadnetwork/storage/pages/retiskip.mu
rm ~/scripts/retiskip.py ~/scripts/retiskip_cache.json
```

Then remove any links to `/page/retiskip.mu` from your other pages, and restart NomadNet.

## Credits

Band conditions and solar data are provided by N0NBH at [hamqsl.com](https://www.hamqsl.com/solar.html). RetiSkip credits the source on the page; please keep that credit if you customize it. RetiSkip is not affiliated with or endorsed by N0NBH.

## See also

[RetiCast](<RetiCast repo URL>): live weather and NWS alerts for your grid square, on your NomadNet pages.
