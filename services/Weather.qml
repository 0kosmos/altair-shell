// SPDX-License-Identifier: GPL-3.0-or-later
pragma Singleton

import QtQuick
import Quickshell
import qs.core

// Weather from Open-Meteo (open-meteo.com: free, no API key). The only data
// sent is the chosen place's coordinates (Settings > Widgets), and only while
// a Weather widget exists (`users` > 0): fetched then and every 30 minutes.
// City search uses Open-Meteo's geocoding API.
Singleton {
    id: root

    property int users: 0
    // A place needs its coordinates too (the name alone once fetched 0°, 0°).
    readonly property bool configured: Config.ready && Config.widgets.weatherCity !== ""
        && !(Config.widgets.weatherLat === 0 && Config.widgets.weatherLon === 0)
    readonly property string city: Config.ready ? Config.widgets.weatherCity : ""
    readonly property real lat: Config.ready ? Config.widgets.weatherLat : 0
    readonly property real lon: Config.ready ? Config.widgets.weatherLon : 0
    readonly property bool fahrenheit: Config.ready && Config.widgets.weatherUnits === "f"
    readonly property string unit: fahrenheit ? "°F" : "°C"

    // ---- Data -------------------------------------------------------------------------
    property bool loaded: false
    property bool failed: false
    property real temp: 0
    property real feels: 0
    property int code: 0
    property bool isDay: true
    property int humidity: 0
    property real wind: 0
    // [{ date, code, max, min }] for today and the next 5 days.
    property var daily: []
    // [{ time, code, temp, isDay }] for the next 6 hours.
    property var hourly: []

    readonly property bool wanted: users > 0 && configured
    onWantedChanged: if (wanted) fetch()
    readonly property string key: lat + "," + lon + "," + fahrenheit
    onKeyChanged: if (wanted) { loaded = false; fetch(); }

    Timer {
        interval: 30 * 60 * 1000
        repeat: true
        running: root.wanted
        onTriggered: root.fetch()
    }

    function fetch(): void {
        const url = "https://api.open-meteo.com/v1/forecast?latitude=" + lat.toFixed(3) + "&longitude=" + lon.toFixed(3)
            + "&current=temperature_2m,apparent_temperature,weather_code,is_day,relative_humidity_2m,wind_speed_10m"
            + "&hourly=temperature_2m,weather_code,is_day&daily=weather_code,temperature_2m_max,temperature_2m_min"
            + "&forecast_days=6&timezone=auto" + (fahrenheit ? "&temperature_unit=fahrenheit&wind_speed_unit=mph" : "");
        const xhr = new XMLHttpRequest();
        xhr.onreadystatechange = () => {
            if (xhr.readyState !== XMLHttpRequest.DONE)
                return;
            try {
                if (xhr.status !== 200)
                    throw "HTTP " + xhr.status;
                parse(JSON.parse(xhr.responseText));
                failed = false;
                loaded = true;
            } catch (e) {
                failed = true;
                console.warn("altair: weather request failed: " + e);
            }
        };
        xhr.open("GET", url);
        xhr.send();
    }

    function parse(d: var): void {
        const c = d.current;
        temp = c.temperature_2m;
        feels = c.apparent_temperature;
        code = c.weather_code;
        isDay = c.is_day === 1;
        humidity = c.relative_humidity_2m;
        wind = c.wind_speed_10m;
        const dl = [];
        for (let i = 0; i < d.daily.time.length; i++)
            dl.push({ date: d.daily.time[i], code: d.daily.weather_code[i], max: d.daily.temperature_2m_max[i], min: d.daily.temperature_2m_min[i] });
        daily = dl;
        // The next 6 hours from now (the API returns whole days, local time).
        const now = new Date(c.time);
        const hl = [];
        for (let i = 0; i < d.hourly.time.length && hl.length < 6; i++) {
            const t = new Date(d.hourly.time[i]);
            if (t > now)
                hl.push({ time: t, code: d.hourly.weather_code[i], temp: d.hourly.temperature_2m[i], isDay: d.hourly.is_day[i] === 1 });
        }
        hourly = hl;
    }

    // ---- WMO weather codes -> icon (Material Symbols) and text -----------------------
    function icon(c: int, day: bool): string {
        if (c === 0) return day ? "sunny" : "clear_night";
        if (c <= 2) return day ? "partly_cloudy_day" : "partly_cloudy_night";
        if (c === 3) return "cloud";
        if (c === 45 || c === 48) return "foggy";
        if (c >= 95) return "thunderstorm";
        if ((c >= 71 && c <= 77) || c === 85 || c === 86) return "weather_snowy";
        return "rainy";
    }
    function text(c: int): string {
        if (c === 0) return "Clear";
        if (c === 1) return "Mostly clear";
        if (c === 2) return "Partly cloudy";
        if (c === 3) return "Cloudy";
        if (c === 45 || c === 48) return "Fog";
        if (c >= 51 && c <= 57) return "Drizzle";
        if (c >= 61 && c <= 67) return c >= 65 ? "Heavy rain" : "Rain";
        if (c >= 71 && c <= 77) return "Snow";
        if (c >= 80 && c <= 82) return "Showers";
        if (c === 85 || c === 86) return "Snow showers";
        if (c >= 95) return "Thunderstorm";
        return "—";
    }
    function deg(v: real): string {
        return Math.round(v) + "°";
    }

    // ---- City search (Settings) -------------------------------------------------------
    property var results: []
    property bool searching: false
    function search(name: string): void {
        name = name.trim();
        if (!name) {
            results = [];
            return;
        }
        searching = true;
        const xhr = new XMLHttpRequest();
        xhr.onreadystatechange = () => {
            if (xhr.readyState !== XMLHttpRequest.DONE)
                return;
            searching = false;
            try {
                const r = JSON.parse(xhr.responseText).results ?? [];
                results = r.map(x => ({ name: x.name, region: [x.admin1, x.country].filter(v => v).join(", "), lat: x.latitude, lon: x.longitude }));
            } catch (e) {
                results = [];
            }
        };
        xhr.open("GET", "https://geocoding-api.open-meteo.com/v1/search?count=6&format=json&language="
            + Qt.locale().name.split("_")[0] + "&name=" + encodeURIComponent(name));
        xhr.send();
    }
    function choose(r: var): void {
        Config.widgets.weatherLat = r.lat;
        Config.widgets.weatherLon = r.lon;
        Config.widgets.weatherCity = r.name;
        results = [];
    }
}
