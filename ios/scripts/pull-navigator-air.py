#!/usr/bin/env python3
"""Pulls the real hourly outdoor air behind the "navigator" data set (Settings › Demo and development).

A made-up travel nurse moves Fresno → Denver → St. Louis over six weeks. Her moments are made up; the air
is not. This writes ios/AsthmaLog/Resources/navigator-air.json:

- Open-Meteo (free, no key): PM2.5 and ozone from its air-quality archive (CAMS model), temperature,
  humidity and wind from its weather model. Six weeks, per city, for the days she is there. No US pollen.
- Ambee (the key in Config/Secrets.xcconfig): the last 2 days in the city she is in now, with pollen.
  Ambee's plan only returns 2 days of history, which is why the rest is Open-Meteo.

Only city-centre coordinates are sent. Run it the day before a demo:  python3 ios/scripts/pull-navigator-air.py
"""
import json, os, re, sys, urllib.parse, urllib.request
from datetime import datetime, timedelta, timezone

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "..", "AsthmaLog", "Resources", "navigator-air.json")
DAYS = 42

# (name, lat, lon, IANA time zone, first day offset, last day offset) — offsets count back from today.
STINTS = [
    ("Fresno", 36.7378, -119.7871, "America/Los_Angeles", 42, 28),
    ("Denver", 39.7392, -104.9903, "America/Denver", 27, 16),
    ("St. Louis", 38.6270, -90.1994, "America/Chicago", 15, 0),
]


def get(url, params, headers=None):
    req = urllib.request.Request(url + "?" + urllib.parse.urlencode(params), headers=headers or {})
    with urllib.request.urlopen(req, timeout=40) as r:
        return json.load(r)


def epoch(iso):
    return int(datetime.fromisoformat(iso).replace(tzinfo=timezone.utc).timestamp())


def open_meteo(lat, lon, start, end):
    aq = get("https://air-quality-api.open-meteo.com/v1/air-quality",
             {"latitude": lat, "longitude": lon, "hourly": "pm2_5,ozone", "start_date": start, "end_date": end, "timezone": "UTC"})
    wx = get("https://api.open-meteo.com/v1/forecast",
             {"latitude": lat, "longitude": lon, "hourly": "temperature_2m,relative_humidity_2m,wind_speed_10m,pressure_msl",
              "temperature_unit": "fahrenheit", "wind_speed_unit": "mph", "start_date": start, "end_date": end, "timezone": "UTC"})
    hours = {}
    for t, pm, o3 in zip(aq["hourly"]["time"], aq["hourly"]["pm2_5"], aq["hourly"]["ozone"]):
        h = hours.setdefault(epoch(t), {})
        if pm is not None: h["pm25"] = round(pm, 1)
        if o3 is not None: h["ozone"] = round(o3 / 1.96)   # µg/m³ → ppb at 25 °C
    for t, f, rh, wind, pres in zip(wx["hourly"]["time"], wx["hourly"]["temperature_2m"], wx["hourly"]["relative_humidity_2m"],
                                    wx["hourly"]["wind_speed_10m"], wx["hourly"]["pressure_msl"]):
        h = hours.setdefault(epoch(t), {})
        if f is not None: h["tempF"] = round(f)
        if rh is not None: h["humidity"] = round(rh)
        if wind is not None: h["wind"] = round(wind, 1)
        if pres is not None: h["pressure"] = round(pres, 1)
    now = datetime.now(timezone.utc).timestamp()
    return [{"t": t, **v} for t, v in sorted(hours.items()) if t <= now and v]


def ambee_key():
    try:
        text = open(os.path.join(HERE, "..", "Config", "Secrets.xcconfig")).read()
    except OSError:
        return None
    m = re.search(r"^AMBEE_API_KEY\s*=\s*(\S+)", text, re.M)
    return m.group(1) if m else None


def ambee(lat, lon):
    """The last 2 days: air quality and pollen, by hour. Empty without a key or when a call fails."""
    key = ambee_key()
    if not key:
        return []
    now = datetime.now(timezone.utc)
    rng = {"lat": lat, "lng": lon, "speciesRisk": "true", "from": (now - timedelta(hours=47)).strftime("%Y-%m-%d %H:00:00"),
           "to": now.strftime("%Y-%m-%d %H:00:00")}
    head = {"x-api-key": key, "Content-type": "application/json"}
    hours = {}

    def slot(iso):
        return int(datetime.fromisoformat(iso.replace("Z", "+00:00")).timestamp()) // 3600 * 3600

    try:
        for s in get("https://api.ambeedata.com/history/by-lat-lng", rng, head).get("data", []):
            when = s.get("createdAt") or s.get("updatedAt")
            if not when: continue
            h = hours.setdefault(slot(when), {})
            if s.get("PM25") is not None: h["pm25"] = round(s["PM25"], 1)
            if s.get("OZONE") is not None: h["ozone"] = round(s["OZONE"])
    except Exception as e:
        print("Ambee air:", e, file=sys.stderr)
    try:
        for e in get("https://api.ambeedata.com/v3/pollen/history", rng, head).get("data", []):
            when, c = e.get("unixTs") or e.get("time") or e.get("timestamp"), e.get("Count") or {}
            if when is None: continue
            t = slot(when) if isinstance(when, str) else int(when) // 3600 * 3600
            h = hours.setdefault(t, {})
            for k, name in (("tree_pollen", "tree"), ("grass_pollen", "grass"), ("weed_pollen", "weed")):
                if c.get(k) is not None: h[name] = c[k]
            sp = e.get("Species") or {}
            if sp: h["species"] = {"tree": sp.get("Tree") or {}, "grass": sp.get("Grass") or {}, "weed": sp.get("Weed") or {},
                                 "others": sp.get("Others")}
    except Exception as e:
        print("Ambee pollen:", e, file=sys.stderr)
    return [{"t": t, **v} for t, v in sorted(hours.items()) if v]


def main():
    today = datetime.now(timezone.utc).date()
    cities = []
    for name, lat, lon, tz, first, last in STINTS:
        start, end = today - timedelta(days=first), today - timedelta(days=last)
        hours = open_meteo(lat, lon, start.isoformat(), end.isoformat())
        cities.append({"name": name, "latitude": lat, "longitude": lon, "timeZone": tz,
                       "from": start.isoformat(), "to": end.isoformat(), "hours": hours})
        print(f"{name}: {len(hours)} hours, {start} to {end}")
    name, lat, lon = STINTS[-1][0], STINTS[-1][1], STINTS[-1][2]
    recent = ambee(lat, lon)
    print(f"Ambee, {name}: {len(recent)} hours")
    out = {"pulledAt": int(datetime.now(timezone.utc).timestamp()), "cities": cities, "ambeeCity": name, "ambee": recent}
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with open(OUT, "w") as f:
        json.dump(out, f, separators=(",", ":"))
    print("Wrote", os.path.normpath(OUT), f"({os.path.getsize(OUT) // 1024} KB)")


if __name__ == "__main__":
    main()
