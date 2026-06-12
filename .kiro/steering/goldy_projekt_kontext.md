---
inclusion: always
---

# GOLDY AI TRADER — Projekt-Kontext

> Diese Datei wird bei jedem Chat automatisch geladen.
> Sie enthält den kompletten Projekt-Stand, damit Kiro auch nach
> einem neuen Chat sofort weiterarbeiten kann.

## Mission

Alex baut einen vollautomatischen Trading-EA für **MetaTrader 4**:
- Macht Screenshots vom Chart
- Schickt sie an OpenAI (GPT-4o-mini)
- KI erkennt visuelle Indikator-Signale (Hände/Pfeile auf schwarzem Hintergrund)
- EA tradet automatisch (BUY/SELL öffnen, schließen)
- Sendet Telegram-Nachrichten in 2 Gruppen (privat + Freunde)

**Symbol:** XAUUSD (meistens), Timeframe M1 (auch M5 möglich)
**Broker:** Roboforex
**Plattform-Setup:** 1 VPS mit mehreren MT4-Instanzen

## Symbol-Zuordnung (FINAL — nicht mehr ändern!)

| Symbol auf Chart | Bedeutung | Code |
|---|---|---|
| **Weisse Hand** | BUY öffnen | `BUY` |
| **Roter Pfeil nach unten** | BUY schließen | `CLOSE_BUY` |
| **Magenta/pinke Hand** | SELL öffnen | `SELL` |
| **Grüner Pfeil nach oben** | SELL schließen | `CLOSE_SELL` |

**Regel:** Hände = Entry, Pfeile = Exit.
Das **neueste** Symbol ist immer **am weitesten rechts** im Chart.

## Architektur (aktueller Stand)

**Hauptansatz seit 11.06.2026:** Alles in EINEM EA = `GOLDY AI TRADER`
(früher waren es 3 separate EAs — wurde verworfen weil zu komplex).

### VPS-Setup
| Terminal | EA | Aufgabe |
|---|---|---|
| MT4 #1 | GOLDY AI TRADER (M1) | KI-Analyse + Trading + Telegram |
| MT4 #2 | GOLDY AI TRADER (M5) | KI-Analyse + Trading + Telegram |
| MT4 #3 (optional) | GOLDY Screenshot | Wave-Chart-Bilder auf Anfrage |

### Telegram
- **1 Bot** in **2 Gruppen**:
  - Gruppe 1: Trade-Nachrichten (New Trade, Win/Loss, Reports)
  - Gruppe 2: Befehle + Dashboard (b, /on, /off, /status, etc.)

## Aktuelle Code-Version: V6.1

**Pfad:** `MT4/Experts/Goldy_AI_Trader_V6.mq4`
**Prompt-Datei:** `MT4/Files/Goldy/prompt_mt4_1min.txt`
(Datei wird zur Laufzeit aus `Common\Files\Goldy\` gelesen)

### Was V6.1 anders macht als V6.0
1. **Screenshot-Crop**: `ChartScreenShot()` mit `ALIGN_RIGHT` statt `WindowScreenShot()`
   → KI sieht nur die rechten Bars, alte Symbole sind physisch nicht im Bild
2. **3 neue Inputs**: `Crop_Aktiv`, `Crop_Breite_Pixel` (Default 350), `Crop_Hoehe_Pixel` (Default 800)
3. **Verbesserter Fallback-Prompt** mit "REGEL NUMMER 1: rechtestes Symbol"

### V6.1 Inputs (Übersicht)
- OPENAI: API_Key, Analyse_Intervall (60), API_Timeout (30)
- TELEGRAM: Bot_Token, Chat_ID, Erlaubte_ID
- TRADING: Lot (0.10), Magic (1001)
- SCREENSHOT-CROP: Aktiv, Breite, Höhe
- SCHWARZE MASKE (BMP): optional, Default Nein
- KI: Prompt_Datei
- NACHRICHT NEUER TRADE: Bild + Felder (Währung, Preis, Richtung, Datum, Uhrzeit, Lot)
- NACHRICHT TRADE GESCHLOSSEN: Bild + Felder (Entry, Close, P/L, Dauer, etc.)
- WIN/LOSS Bilder

### Trade-Logik (im EA)
- Kein Trade offen → nur Hände akzeptieren (BUY/SELL öffnen)
- Trade offen → nur Pfeile akzeptieren (CLOSE_BUY/CLOSE_SELL)
- Signal nur reagieren wenn `confidence == high`

## Bekannte Probleme & Lösungen

| Problem | Status | Lösung |
|---|---|---|
| KI ignorierte rote Pfeile, meldete immer `BUY` | Gelöst (V6.1) | Crop + besserer Prompt |
| KI verwechselte Magenta/Gelb | Gelöst | BUY-Hand auf weiß umgestellt |
| Trade-Linien verwirrten KI | Gelöst | `CHART_SHOW_TRADE_LEVELS = false` + `clrNONE` |
| Telegram 409 Conflict | Gelöst | Verschiedene Bots für Trader/Reporter |
| OpenAI Markdown-Wrapper (```json) | Gelöst | Robusterer Response-Parser |

## Bilder (gehostet auf postimg.cc)

```
new-trade.jpg      https://i.postimg.cc/tJ5wCt20/new-trade.jpg
close-trade.jpg    https://i.postimg.cc/Xv0PpD9j/close-trade.jpg
winning.jpg        https://i.postimg.cc/pLy4Rjjg/winning.jpg
loss.jpg           https://i.postimg.cc/J0PYW7zr/loss.jpg
session-on.jpg     https://i.postimg.cc/50wB5V7Q/session-on.jpg
session-off.jpg    https://i.postimg.cc/Bbp2yCGZ/session-off.jpg
day-report.jpg     https://i.postimg.cc/tJCDD0tx/day-report.jpg
weekly-report.jpg  https://i.postimg.cc/c4CXnSJC/weekly-report.jpg
```

## Telegram-Setup

- **User-ID Alex**: `479441154`
- **Private Gruppe (Befehle)**: `-1003773626278` → @GoldBot888
- **Freunde-Gruppe (öffentlich)**: `-1003761007396` → @GoldyAIGroup
- Bot in privater Gruppe: @GoldBot888_Bot
- Bot für Trader: @BinaryMoneyPrinterSignalebot

## Planmäßig noch zu bauen

- [ ] Geplant: Scheduler (Wochentage, Zeitfenster)
- [ ] Geplant: News-Filter (faireconomy API, High-Impact Events)
- [ ] Geplant: ADX-Filter (M1/M5)
- [ ] Geplant: RSI-Filter (M1/M5)
- [ ] Auto-Status-Meldung bei offenen Trades
- [ ] Tages-/Wochen-Bericht
- [ ] Lizenz-System (für später, wenn Alex EA weitergibt)

## Erlaubte URLs in MT4 Optionen

```
https://api.openai.com           (OpenAI API)
https://api.telegram.org         (Telegram Bot API)
https://nfs.faireconomy.media    (News-Kalender)
https://i.postimg.cc             (Bild-Hosting für Telegram)
```

## Konventionen / Sprache

- **Antwort-Sprache**: Immer **Deutsch** (Alex' Muttersprache)
- **Code-Kommentare**: Deutsch
- **Variablen-Namen**: Deutsch (z.B. `Crop_Breite_Pixel`)
- **Logs/Print**: Deutsch
- **Keine Umlaute** in Strings die per Telegram/HTTP gesendet werden (UTF-8 Probleme vermeiden)
- **JSON-Strings im Code**: Mit `CharToString(34)` statt `\"` arbeiten

## Wichtige technische Details

- MT4 nutzt **MQL4** (nicht MQL5!) — Trade-Funktionen: `OrderSend`, `OrderClose`
- Ordner-Struktur:
  - EA-Code: `MQL4\Experts\`
  - Bilder/BMP: `MQL4\Images\`
  - Prompt-Datei: `Common\Files\Goldy\prompt_mt4_1min.txt`
  - Signal-Files (falls EA-zu-EA Kommunikation): `Common\Files\Goldy_Shared\`
- `WindowScreenShot()` ist veraltet → besser `ChartScreenShot()` mit `ALIGN_RIGHT`
- `CHART_AUTOSCROLL = true` damit immer der rechte Bereich angezeigt wird
- Magic Number: 1001 für M1-Instanz, 1002 für M5-Instanz (etc.)

## Wichtige Architektur-Entscheidungen (kurz erklärt)

- **EIN EA statt drei**: Weniger Komplexität, kein Datei-Transfer nötig
- **Schwarzer Chart-Hintergrund**: Indikator-Symbole sind besser für KI sichtbar
- **GPT-4o-mini**: Günstiger als GPT-4o (~38 USD/Monat), reicht für visuelle Erkennung
- **Crop statt Maske**: Maske kann übersehen werden, Crop entfernt physisch alte Bars
- **Externe Prompt-Datei**: Prompt änderbar ohne EA-Recompile
- **Inputs auf Deutsch**: Bessere UX für Alex
