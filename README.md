# PulseTrack

A sleek, Whoop-inspired health & fitness tracking app for iPhone — **no AI, all deterministic formulas**. It reads everything from Apple Health (including any sensors you've paired through Health: Apple Watch, chest straps, rings, etc.) and turns it into daily Recovery, Strain, Sleep and Heart Rate insights.

## Features

- **Recovery score (0–100)** — blends HRV (SDNN), resting heart rate, sleep quality, respiratory rate and blood oxygen against your personal 30-day rolling baseline.
- **Day Strain (0–21)** — logarithmic cardiovascular load derived from time-in-heart-rate-zones + active energy.
- **Sleep performance** — sleep stages (Deep/REM/Core/Awake), efficiency, and a strain-adjusted sleep-need model.
- **Heart rate** — all-day min/avg/max, live graph, and 5 training zones (Tanaka max-HR estimate from your age).
- **Vitals dashboard** — RHR, HRV, respiratory rate, SpO₂, active calories, steps.
- **Trends** — 7- and 30-day history bars for every core metric.
- Modern dark UI with metric rings, gradients and rounded typography.

## Requirements

- macOS with **Xcode 16+**
- iPhone running **iOS 17+** (HealthKit is not available in the Simulator for most data)
- An Apple Developer account (free tier works for on-device testing)

## Build & Run

1. Open `PulseTrack.xcodeproj` in Xcode.
2. Select the **PulseTrack** target → Signing & Capabilities → choose your Team. The **HealthKit** capability and Health usage strings are already configured.
3. Set the bundle identifier to something unique (default `com.zkardes.PulseTrack`).
4. Plug in your iPhone, select it as the run destination, and press **Run**.
5. On first launch, tap **Connect Apple Health** and grant read access.

## How the scores work

All analytics live in `PulseTrack/Managers/HealthAnalytics.swift`. They are pure functions — rolling baselines and weighted models — so results are fully explainable and reproducible. No machine learning, no network calls, your data never leaves the device.

## Project structure

```
PulseTrack/
├── PulseTrackApp.swift          # App entry
├── DesignSystem/Theme.swift     # Colors, typography, layout
├── Models/HealthModels.swift    # Data types
├── Managers/
│   ├── HealthKitManager.swift   # Reads all HealthKit data
│   ├── HealthAnalytics.swift    # Scoring formulas
│   ├── WorkoutType+Display.swift
│   └── Formatters.swift
└── Views/                       # Dashboard, Recovery, Strain, Sleep, Heart
```

## Privacy

PulseTrack only **reads** from Apple Health and processes everything locally. It never writes data back and makes no network requests.
