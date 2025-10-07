# ReLife – SwiftUI Demo

ReLife ist eine SwiftUI-Demo-App, die einen Vitalitäts- und Gesundheitsfeed mit simulierten Sensordaten zeigt. Der Fokus liegt auf modernen UI-Mustern (Liquid-Glass-Optik, Apple Charts) und einem klaren Flow von der Demo-Verbindung bis zu Auswertungen, Notizen und Export.

## Inhalt & Features
- **Demo-Verbindung** (`Views/ConnectScreen.swift`): Laden zufälliger, plausibler Vitaldaten für die letzten 10 Tage.
- **Today-Tab** (`Views/Tabs/TodayView.swift`): ReLife Score, Balance-Level, Kennzahlenkarten, Apple-Charts nach Zeitfenster, Schnellaktionen (Stress-Marker, Notiz).
- **Trends-Tab** (`Views/Tabs/TrendsView.swift`): 7-Tage-Vitality-Timeline, EDA-Zonenkarten, Kennzahlen-Statistiken, CSV-Export via Share Sheet.
- **Protokoll-Tab** (`Views/Tabs/LogView.swift`): Notizen mit Tag-Filtern, Hinzufügen/Löschen über `AddNoteSheet`.
- **Einstellungen** (`Views/Tabs/SettingsView.swift`): Farbmodus, Temperatur-Einheit, Demo-Daten neu laden, Daten löschen, Statushinweise.
- **AppState** (`AppState.swift`): Zentrale Datenhaltung (`@ObservableObject`) inkl. Demo-Datengenerierung, Vitality-Berechnung, Notizenverwaltung, Farb-Helper.
- **UI-Komponenten** (`Views/Components`): Buttons, Chart-/Karten-Bausteine, Tag Pills, ActivityView (Share Sheet).
- **Tests** (`ReLifeTests`, `ReLifeUITests`): Gerüste für Swift Testing und XCTest UI-Tests.

## Architekturüberblick
- **SwiftUI + NavigationStack/TabView**: Struktur mit einem `AppState` als `@EnvironmentObject`, der den gesamten Flow steuert.
- **Modelle & Auswertungen**: `Sample`, `Note`, `VitalitySnapshot` sowie Berechnungen für Vitality Score, Balance-Level, Trendtexte.
- **Charts**: Apple `Charts` Framework für Linien-, Flächen- und Balkendarstellungen.
- **UIKit-Interop**: Haptik im `PrimaryButton` sowie CSV-Export via `UIActivityViewController`.
- **Designsystem**: Markenfarben aus `Assets.xcassets`, Glasoptik über Material-Hintergründe, SF Symbols.

## Voraussetzungen & Start
1. Xcode 15 oder neuer (iOS 16+ wegen `NavigationStack` und `Charts`).
2. Projekt öffnen (`ReLife.xcodeproj`) und auf einem iOS-Simulator oder Gerät starten.
3. Beim ersten Start im Connect-Screen auf „Verbinden“ tippen, um Demo-Daten zu laden.
4. CSV-Export testen: Im Trends-Tab „CSV exportieren“ antippen (öffnet Share Sheet).

## Bekannte Einschränkungen
- Keine echte Sensor-/Cloud-Anbindung, keine Persistenz – Daten gehen nach App-Beendigung verloren.
- App-Icon-Set ist Platzhalter (JPEG); für Release vollständige PNG-Sets erzeugen.
- Swift Testing (`import Testing`) erfordert eine aktuelle Toolchain; bei älteren Xcode-Versionen Tests anpassen/entfernen.
- Keine Lokalisierung; Texte aktuell nur auf Deutsch.

## Offene Baustellen & Ideen
1. **Persistenz**: Core Data/SwiftData oder File-basiert, um Notizen und Messwerte zu behalten.
2. **Echte Datenquellen**: Anbindung an HealthKit, Wearables oder API.
3. **Analytics & Insights**: Weitere Kennzahlen (z. B. HRV, Schlaf), Vergleich zum Wochendurchschnitt.
4. **Internationalisierung**: Lokalisierungen (Deutsch/Englisch) und String-Management.
5. **Tests ausbauen**: Unit-Tests für Vitality-Berechnung, UI-Tests für Kernflows, CSV-Validierung.
6. **Design-Feinschliff**: Vollständiges App-Icon-Set, Onboarding, Accessibility-Audit, adaptives Layout für iPad.

## Nützliche Dateien
- `PROJECT_OVERVIEW_DE.txt`: Detailübersicht (High-Level) zur App – gute Ergänzung zur README.
- `Assets.xcassets`: Farben (`BrandPrimary`, `BrandSecondary`, `CardBG`) & App Icon.
- `ReLifeApp.swift`: Einstiegspunkt, hängt `AppState` an und setzt Farbschema.

## Weiteres Vorgehen
Nach dem ersten Build empfiehlt es sich, den Datenfluss in `AppState.swift` nachzuvollziehen, anschließend die Tabs in Xcode vorzuschauen (`Canvas/#Preview`). Für neue Features zuerst die Vitality-Logik prüfen, damit UI und Kennzahlen konsistent bleiben.
