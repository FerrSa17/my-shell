pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// The weather in Saint Petersburg from Open-Meteo (no key needed), refreshed every 20 min while
// the control center is open (`active`; a reading under 10 minutes old is reused). `glyph` is a Material Symbols name for the WMO weather code.
Singleton {
    id: root
    readonly property real latitude: 59.94
    readonly property real longitude: 30.31
    property bool active: false
    property real fetchedAt: 0
    property bool ready: false
    property real temp: 0
    property real feels: 0
    property int code: 0
    property bool day: true
    readonly property string tempText: ready ? Math.round(temp) + "°" : ""
    readonly property string glyph: {
        const c = code
        if (c === 0) return day ? "clear_day" : "clear_night"
        if (c <= 2) return day ? "partly_cloudy_day" : "partly_cloudy_night"
        if (c === 3) return "cloud"
        if (c <= 48) return "foggy"
        if (c <= 67 || (c >= 80 && c <= 82)) return "rainy"
        if (c <= 77 || c === 85 || c === 86) return "weather_snowy"
        return "thunderstorm"
    }
    readonly property string description: {
        const c = code
        return c === 0 ? "Clear" : c <= 2 ? "Partly cloudy" : c === 3 ? "Overcast" : c <= 48 ? "Fog"
            : c <= 57 ? "Drizzle" : c <= 67 ? "Rain" : c <= 77 ? "Snow" : c <= 82 ? "Showers" : c <= 86 ? "Snow showers" : "Thunderstorm"
    }

    Process {
        id: fetch
        command: ["curl", "-s", "-m", "15", "https://api.open-meteo.com/v1/forecast?latitude=" + root.latitude + "&longitude=" + root.longitude
            + "&current=temperature_2m,apparent_temperature,weather_code,is_day&timezone=auto"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const c = JSON.parse(text).current
                    root.temp = c.temperature_2m; root.feels = c.apparent_temperature
                    root.code = c.weather_code; root.day = c.is_day === 1
                    root.ready = true; root.fetchedAt = Date.now()
                } catch (e) {}
            }
        }
    }
    function refresh(force) { if (!fetch.running && (force || Date.now() - fetchedAt > 600000)) fetch.running = true }
    // Every 20 min, sooner (1 min) while it has never loaded (the network may come up late).
    Timer { interval: root.ready ? 1200000 : 60000; running: root.active; repeat: true; triggeredOnStart: true; onTriggered: root.refresh(false) }
}
