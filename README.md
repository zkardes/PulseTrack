# PulseTrack

Eine schlanke, Whoop-inspirierte Health- & Fitness-App für iPhone — **ohne KI, ohne Apple Health**. PulseTrack bezieht seine Daten aus zwei Quellen:

1. **Withings Cloud API** (OAuth2) — z. B. für die **Withings Scanwatch 2**: Aktivität, Schlaf, Herzfrequenz, SpO₂.
2. **Bluetooth LE (Core Bluetooth)** — direkte Live-Verbindung zu Sensoren mit Standard-**Heart Rate Service (0x180D)**, z. B. GEOID-Tracker und Brustgurte.

Daraus berechnet die App täglich Recovery, Belastung (Strain), Schlaf und Herzfrequenz-Insights — alles mit **deterministischen Formeln**, komplett auf dem Gerät.

## Kein bezahltes Apple-Programm nötig

HealthKit wurde entfernt. Du brauchst **nur einen kostenlosen Apple-ID Developer Account** ("Personal Team") in Xcode, um die App auf deinem eigenen iPhone zu installieren. Einschränkungen der kostenlosen Variante: App läuft nur auf deinen Geräten und muss alle 7 Tage neu aus Xcode installiert werden.

## Setup Withings API

1. Registriere eine App unter https://developer.withings.com → Partner Hub → **Create an application** (Typ *Public API / Developer*). Der Login (z. B. per Apple ID) genügt **nicht** — du musst dort explizit eine App anlegen.
2. Hinterlege als **Callback/Redirect URI**: `pulsetrack://withings-callback`
3. Du erhältst **Client ID** und **Client Secret**.
4. Trage beides in `PulseTrack/Managers/WithingsConfig.swift` ein (Vorlage: `WithingsConfig.example.txt`).

⚠️ **Das Client Secret niemals committen.** `WithingsConfig.swift` steht bereits in `.gitignore`.

## Bluetooth-Sensor koppeln

Tab **Geräte** → **Sensoren suchen** → Gerät antippen. Es funktioniert jeder Sensor, der das standardisierte BLE Heart Rate Profil sendet. Die Withings Scanwatch 2 selbst sendet **kein** offenes BLE-Profil und läuft daher nur über die Cloud API.

## Build & Run

1. `PulseTrack.xcodeproj` in **Xcode 16+** öffnen.
2. Target → Signing & Capabilities → dein (kostenloses) Team wählen. Es ist **keine** HealthKit-Capability nötig.
3. iPhone (iOS 17+) anschließen, **Run**.

## Projektstruktur

```
PulseTrack/
├── PulseTrackApp.swift
├── DesignSystem/Theme.swift
├── Models/               # HealthModels, WithingsModels
├── Managers/
│   ├── WithingsConfig.swift    # (gitignored) Client ID & Secret
│   ├── WithingsClient.swift    # OAuth2 + API
│   ├── TokenStore.swift        # Keychain
│   ├── BLEManager.swift        # Core Bluetooth
│   ├── DataStore.swift         # Withings + BLE -> DayMetrics
│   ├── HealthAnalytics.swift   # Score-Formeln (keine KI)
│   └── Formatters.swift
└── Views/                # Dashboard, Recovery, Strain, Sleep, Heart, Settings
```

## Privacy

Alle Berechnungen laufen lokal. Withings-Tokens liegen im iOS Keychain. Es werden ausschließlich Requests an die Withings API gestellt; keine weiteren Server.
