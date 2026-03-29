# ✈️ Contrail

**A focus timer disguised as a flight simulator.**

Turn your deep work sessions into virtual flights across the globe.
Pick a destination, board your flight, and stay focused until you land.

![macOS](https://img.shields.io/badge/macOS-14.0%2B-000000?style=flat&logo=apple&logoColor=white)
![Swift](https://img.shields.io/badge/Swift-5.9-FA7343?style=flat&logo=swift&logoColor=white)
![SwiftUI](https://img.shields.io/badge/SwiftUI-Declarative-007AFF?style=flat)
![SwiftData](https://img.shields.io/badge/SwiftData-Persistence-34C759?style=flat)

</div>

---

## 🌍 What is Contrail?

Contrail reimagines the Pomodoro timer as a flight experience. Instead of watching a generic countdown, you:

1. **Choose a destination** on an interactive dark globe map
2. **Board your flight** — the focus timer matches the real flight duration
3. **Stay focused** while your virtual airplane crosses continents
4. **Land** and watch your flight log grow

The app calculates real great-circle distances and flight durations between 6,000+ airports worldwide using the Haversine formula. A 4-hour focus session? That's Berlin → Dubai. A quick 25-minute sprint? Try London → Paris.

---

## ✨ Features

| Feature | Description |
|---|---|
| 🗺️ **Dark Globe Map** | Interactive satellite map with 3D globe view, reachability circles, and glowing destination pins |
| ⏱️ **Flight Timer** | Immersive countdown with boarding phases (Boarding → Takeoff → Cruising → Landing → Arrived) |
| 📊 **Trends & Analytics** | Weekly focus charts, total distance traveled, streak tracking, and frequent routes |
| 🕐 **Flight History** | Complete log of all completed focus sessions with route details |
| 🎨 **Nocturnal UI** | Near-black theme with amber glow accents, glassmorphism, and smooth animations |
| 🗺️ **Map Style Picker** | Choose between Standard, Satellite, or Hybrid map views |
| 🔊 **Ambient Sound** | Optional cabin ambience during focus sessions |
| 💾 **Persistent Data** | All sessions saved via SwiftData — your flight log survives app restarts |

---

## 🏗️ Architecture

```
Contrail/
├── ContrailApp.swift          # App entry point + SwiftData container
├── ContentView.swift          # Sidebar navigation (Journey, In Progress, History, Trends, Settings)
├── MapPickerView.swift        # Dark globe map + time slider + destination selection
├── TimerView.swift            # Focus countdown + flight progress + ambient sound
├── StatsView.swift            # Flight history log with glassmorphic cards
├── TrendsView.swift           # Weekly focus charts + analytics
├── SettingsView.swift         # Map style, departure airport, sound preferences
├── Theme.swift                # Design system — nocturnal palette, gradients, typography
├── Airport.swift              # Airport data model
├── Session.swift              # SwiftData model for completed sessions
├── FlightCalculator.swift     # Haversine distance + flight duration calculations
├── AirportDataService.swift   # CSV parser + airport search + reachability filtering
├── SoundManager.swift         # AVFoundation ambient sound manager
└── Resources/
    └── airports.csv           # ~85K airports from OurAirports (filtered to ~6K with IATA codes)
```

### Data Flow

```
MapPickerView ──(select destination)──► ActiveSessionInfo ──► TimerView
                                                                  │
                                                          (on complete)
                                                                  │
                                                              Session ──► SwiftData
                                                                  │
                                                    StatsView / TrendsView
```

---

## 🚀 Getting Started

### Requirements

- **macOS 14.0+** (Sonoma or later)
- **Xcode 15+** with Swift 5.9
- No external dependencies — pure Apple frameworks

### Run

1. **Clone the repository**
   ```bash
   git clone https://github.com/idevanshrai/Contrail.git
   cd Contrail
   ```

2. **Open in Xcode**
   ```bash
   open Contrail.xcodeproj
   ```

3. **Build and Run**
   - Select the `Contrail` scheme
   - Choose `My Mac` as the destination
   - Press `⌘R` to run

   Or from the command line:
   ```bash
   xcodebuild build -project Contrail.xcodeproj -scheme Contrail \
     -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO
   ```

### First Launch

- The app defaults to **Berlin (BER)** as your departure airport
- The map defaults to **Satellite** view (dark globe)
- Drag the time slider to set your focus duration (5 min – 4 hours)
- Tap a destination pin on the map, then click **Start Journey**

---

## 🎨 Design

Contrail's UI is inspired by [FocusFlights](https://apps.apple.com/app/focusflight-deepfocus-timer/id6503753553) — a premium dark nocturnal aesthetic:

- **Near-black background** (`#0A0A0F`) for an immersive, distraction-free environment
- **Amber glow** accents for flight paths and interactive highlights
- **Glassmorphism** via `UltraThinMaterial` on overlays, cards, and controls
- **Time-of-day greetings** — "Good morning!", "Good evening!", etc.
- **Smooth spring animations** on all UI transitions

---

## 🧮 How Flight Durations Work

Contrail uses the **Haversine formula** to calculate great-circle distances between airports, then converts to flight duration at a cruising speed of **900 km/h**:

```
distance = 2 × R × arcsin(√(sin²(Δlat/2) + cos(lat₁) × cos(lat₂) × sin²(Δlon/2)))
duration = distance / 900 km/h
```

This means focus times correspond to real-world flight durations:

| Route | Distance | Focus Time |
|---|---|---|
| LHR → CDG | 344 km | ~23 min |
| JFK → LAX | 3,974 km | ~4h 25m |
| BER → DXB | 4,830 km | ~5h 22m |

---

## 🗂️ Data Source

Airport data comes from [OurAirports](https://ourairports.com/data/) — an open database of ~85,000 airports worldwide. Contrail filters this to ~6,000 airports that have IATA codes and are classified as large or medium airports.

---

## 📄 License

This project is open source. Feel free to fork, modify, and use it for your own productivity needs.

---

<div align="center">

*Stay focused. Fly farther.* ✈️

