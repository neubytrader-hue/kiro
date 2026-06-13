//+------------------------------------------------------------------+
//|                                    Goldy_AI_Trader_V6_6.mq4      |
//|                                  GOLDY AI TRADER V 6.6            |
//|                                  Copyright 2026, Alex             |
//+------------------------------------------------------------------+
//|  CHANGES V6.6 (vs V6.5):                                          |
//|  - UMDREHEN-Modus: max 1 Trade pro Richtung (kein Pyramiding)     |
//|    -> Wenn schon SELL offen + neues SELL-Signal -> ignorieren     |
//|    -> Macht Sinn bei Sternen die bleiben bis anderer kommt        |
//|                                                                   |
//|  CHANGES V6.5 (vs V6.4):                                          |
//|  - KI-Modell als Input + Bild-Detail (high/low)                   |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Alex"
#property version   "6.60"
#property description "GOLDY AI TRADER V 6.6 - Umdrehen ohne Pyramiding"
#property strict

//+------------------------------------------------------------------+
//| ENUMS                                                            |
//+------------------------------------------------------------------+
enum ENUM_JN { Nein = 0, Ja = 1 };

//+------------------------------------------------------------------+
//| EINGABE-PARAMETER                                                |
//+------------------------------------------------------------------+
input string   __API_Header       = "==== OPENAI ====";
input string   API_Key            = "DEIN_KEY_HIER";
input int      Analyse_Intervall  = 60;
input int      API_Timeout        = 30;
//==== NEU IN V6.5: KI-MODELL + BILD-DETAIL =============================
input string   KI_Modell          = "gpt-4o-mini";  // gpt-4o-mini, gpt-4o, gpt-5-mini, gpt-5.4-mini, gpt-4.1-mini
input string   Bild_Detail        = "high";         // low (billig, Bild auf 512x512) oder high (teurer, volle Aufloesung)
//=======================================================================

input string   __Telegram_Header  = "==== TELEGRAM ====";
input string   Bot_Token          = "DEIN_TOKEN";
input string   Chat_ID            = "";
input string   Erlaubte_ID        = "";

input string   __Trading_Header   = "==== TRADING ====";
input double   Lot                = 0.10;
input int      Magic              = 1001;

//==== NEU IN V6.2: MEHRERE TRADES (PYRAMIDING) =========================
input string   __Multi_Header     = "==== MEHRERE TRADES (Pyramiding) ====";
input int      Max_Trades_Pro_Richtung = 3;    // Max gleichzeitige Trades pro Richtung
input int      Min_Sekunden_Zw_Trades  = 120;  // Cooldown zwischen 2 Trades gleicher Richtung
//=======================================================================

//==== NEU IN V6.4: UMDREHEN-MODUS ======================================
input string   __Umdrehen_Header  = "==== UMDREHEN-MODUS (fuer Sterne-Indikator) ====";
input ENUM_JN  Modus_Umdrehen     = Nein;  // Ja = Gegen-Trades schliessen + neuen oeffnen
//=======================================================================

//==== NEU IN V6.1: SCREENSHOT-CROP =====================================
input string   __Crop_Header      = "==== SCREENSHOT-CROP (KI sieht nur rechte Bars) ====";
input ENUM_JN  Crop_Aktiv         = Ja;     // Crop aktivieren
input int      Crop_Breite_Pixel  = 350;    // Breite (kleiner = weniger alte Symbole)
input int      Crop_Hoehe_Pixel   = 800;    // Hoehe
//=======================================================================

//==== NEU IN V6.3: DEBUG-BILD ==========================================
input string   __Debug_Header     = "==== DEBUG ====";
input ENUM_JN  Debug_Bild_Speichern = Ja;  // Bild fuer KI in MQL4\Files\ behalten (zum Pruefen)
//=======================================================================

input string   __Maske_Header     = "==== SCHWARZE MASKE (BMP) ====";
input ENUM_JN  Maske_Aktiv        = Nein;
input string   Maske_Datei        = "black_mask.bmp";
input int      Maske_X            = 0;
input int      Maske_Y            = 0;

input string   __Prompt_Header    = "==== KI ====";
input string   Prompt_Datei       = "Goldy\\prompt_mt4_1min.txt";

input string   __NT_Header        = "==== NACHRICHT: NEUER TRADE ====";
input ENUM_JN  NT_Bild_Senden     = Ja;
input ENUM_JN  NT_Waehrung        = Ja;
input ENUM_JN  NT_Preis           = Ja;
input ENUM_JN  NT_Richtung        = Ja;
input ENUM_JN  NT_Datum           = Ja;
input ENUM_JN  NT_Uhrzeit         = Ja;
input ENUM_JN  NT_Lot             = Nein;

input string   __CT_Header        = "==== NACHRICHT: TRADE GESCHLOSSEN ====";
input ENUM_JN  CT_Bild_Senden     = Ja;
input ENUM_JN  CT_Waehrung        = Ja;
input ENUM_JN  CT_Entry           = Ja;
input ENUM_JN  CT_Close           = Ja;
input ENUM_JN  CT_PL              = Ja;
input ENUM_JN  CT_Dauer           = Ja;
input ENUM_JN  CT_Datum           = Ja;
input ENUM_JN  CT_Uhrzeit         = Ja;
input ENUM_JN  CT_Lot             = Nein;

input string   __WL_Header        = "==== NACHRICHT: WIN / LOSS ====";
input ENUM_JN  Win_Bild           = Ja;
input ENUM_JN  Loss_Bild          = Ja;

//+------------------------------------------------------------------+
//| BILD-URLS                                                        |
//+------------------------------------------------------------------+
string NewTrade_URL  = "https://i.postimg.cc/tJ5wCt20/new-trade.jpg";
string Winning_URL   = "https://i.postimg.cc/pLy4Rjjg/winning.jpg";
string Loss_URL      = "https://i.postimg.cc/J0PYW7zr/loss.jpg";
string CloseTrade_URL = "https://i.postimg.cc/Xv0PpD9j/close-trade.jpg";

//+------------------------------------------------------------------+
//| GLOBALE VARIABLEN                                                |
//+------------------------------------------------------------------+
string   g_prompt = "";
string   g_letztes_signal = "NONE";
uint     g_letzte_analyse = 0;
datetime g_letzter_buy_zeit  = 0;   // V6.2: Cooldown fuer BUY-Pool
datetime g_letzter_sell_zeit = 0;   // V6.2: Cooldown fuer SELL-Pool

//+------------------------------------------------------------------+
//| OnInit                                                            |
//+------------------------------------------------------------------+
int OnInit()
{
   // Prompt laden
   g_prompt = PromptLaden(Prompt_Datei);
   if(StringLen(g_prompt) == 0)
   {
      // VERBESSERTER Fallback-Prompt (V6.1)
      g_prompt =
         "Du analysierst ein Trading-Chart auf schwarzem Hintergrund.\n"
         "REGEL NUMMER 1: Finde das Symbol am weitesten RECHTS (groesste X-Koordinate). "
         "Dieses ist die Antwort. Alle anderen Symbole IGNORIEREN.\n"
         "SYMBOL-TYPEN:\n"
         "- WEISSE HAND        -> signal=BUY\n"
         "- ROTER PFEIL unten  -> signal=CLOSE_BUY\n"
         "- MAGENTA/PINKE HAND -> signal=SELL\n"
         "- GRUENER PFEIL oben -> signal=CLOSE_SELL\n"
         "- Sonst              -> signal=NONE\n"
         "Antworte NUR mit JSON: {\"signal\":\"...\",\"confidence\":\"high|medium|low\",\"reason\":\"...\"}";
   }

   // Chart sauber
   ChartSetInteger(0, CHART_COLOR_BACKGROUND, clrBlack);
   ChartSetInteger(0, CHART_COLOR_FOREGROUND, clrBlack);
   ChartSetInteger(0, CHART_COLOR_CANDLE_BULL, clrBlack);
   ChartSetInteger(0, CHART_COLOR_CANDLE_BEAR, clrBlack);
   ChartSetInteger(0, CHART_COLOR_CHART_UP, clrBlack);
   ChartSetInteger(0, CHART_COLOR_CHART_DOWN, clrBlack);
   ChartSetInteger(0, CHART_COLOR_CHART_LINE, clrBlack);
   ChartSetInteger(0, CHART_COLOR_GRID, clrBlack);
   ChartSetInteger(0, CHART_COLOR_VOLUME, clrBlack);
   ChartSetInteger(0, CHART_COLOR_ASK, clrBlack);
   ChartSetInteger(0, CHART_COLOR_BID, clrBlack);
   ChartSetInteger(0, CHART_COLOR_STOP_LEVEL, clrBlack);
   ChartSetInteger(0, CHART_SHOW_GRID, false);
   ChartSetInteger(0, CHART_SHOW_OHLC, false);
   ChartSetInteger(0, CHART_SHOW_VOLUMES, 0);
   ChartSetInteger(0, CHART_SHOW_TRADE_LEVELS, false);
   ChartSetInteger(0, CHART_AUTOSCROLL, true);
   ChartRedraw(0);

   // Schwarze Maske (BMP) platzieren
   if(Maske_Aktiv == Ja) MaskePlatzieren();

   // Chart-Groesse anzeigen
   Print("Chart Breite: ", ChartGetInteger(0, CHART_WIDTH_IN_PIXELS), " Pixel");
   Print("Chart Hoehe: ", ChartGetInteger(0, CHART_HEIGHT_IN_PIXELS), " Pixel");

   // Crop-Status anzeigen
   if(Crop_Aktiv == Ja)
      Print("CROP AKTIV: Screenshot ", Crop_Breite_Pixel, "x", Crop_Hoehe_Pixel,
            " (rechtsbuendig - alte Symbole werden NICHT mit gerendert)");
   else
      Print("CROP AUS: kompletter Chart wird gesendet");

   // Trade-Status pruefen
   int buys  = ZaehleOffeneTrades(OP_BUY);
   int sells = ZaehleOffeneTrades(OP_SELL);

   EventSetTimer(1);
   Print("=== GOLDY AI TRADER V6.6 gestartet ===");
   Print("KI-Modell: ", KI_Modell, " | Bild-Detail: ", Bild_Detail);
   Print("Intervall: ", Analyse_Intervall, " Sek");
   Print("Pyramiding: max ", Max_Trades_Pro_Richtung, " Trades pro Richtung, Cooldown ", Min_Sekunden_Zw_Trades, "s");
   if(Modus_Umdrehen == Ja)
      Print("UMDREHEN-MODUS AKTIV: Gegen-Trades werden bei neuem Signal automatisch geschlossen");
   else
      Print("Modus GETRENNT: BUY/SELL = oeffnen, CLOSE_BUY/CLOSE_SELL = schliessen");
   Print("Aktuell offen: BUY=", buys, "/", Max_Trades_Pro_Richtung, " SELL=", sells, "/", Max_Trades_Pro_Richtung);

   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
   EventKillTimer();
   ObjectDelete("GOLDY_MASKE");
   Print("=== GOLDY AI TRADER V6.6 beendet ===");
}

//+------------------------------------------------------------------+
//| HAUPTLOGIK (V6.2: Multi-Trade / Pyramiding)                      |
//+------------------------------------------------------------------+
void OnTimer()
{
   uint jetzt = GetTickCount();
   if(g_letzte_analyse > 0 && (jetzt - g_letzte_analyse) < (uint)Analyse_Intervall * 1000)
      return;
   g_letzte_analyse = jetzt;

   string signal = KI_Analyse();

   // Aktuellen Pool-Stand ermitteln
   int buys  = ZaehleOffeneTrades(OP_BUY);
   int sells = ZaehleOffeneTrades(OP_SELL);

   Print("KI-Signal: ", signal,
         " | Offen: BUY=", buys, "/", Max_Trades_Pro_Richtung,
         " SELL=", sells, "/", Max_Trades_Pro_Richtung);

   //--- BUY OEFFNEN -------------------------------------------------
   if(signal == "BUY")
   {
      // V6.6: Im UMDREHEN-Modus max 1 Trade pro Richtung
      if(Modus_Umdrehen == Ja && buys >= 1)
      {
         Print("BUY ignoriert - schon ", buys, " BUY offen (UMDREHEN: nur 1 pro Richtung)");
         return;
      }
      // V6.4: Im UMDREHEN-Modus erst alle SELL schliessen
      if(Modus_Umdrehen == Ja && sells > 0)
      {
         Print(">>> UMDREHEN: Schliesse alle ", sells, " SELL-Trades");
         SchliesseAlleTrades(OP_SELL);
         g_letzter_sell_zeit = 0;
         sells = 0;  // wurden ja gerade geschlossen
      }
      if(buys >= Max_Trades_Pro_Richtung)
      {
         Print("BUY ignoriert - Max erreicht (", buys, "/", Max_Trades_Pro_Richtung, ")");
         return;
      }
      int sek_seit_letztem = (g_letzter_buy_zeit > 0) ? (int)(TimeCurrent() - g_letzter_buy_zeit) : 999999;
      if(sek_seit_letztem < Min_Sekunden_Zw_Trades)
      {
         int rest = Min_Sekunden_Zw_Trades - sek_seit_letztem;
         Print("BUY Cooldown - noch ", rest, "s warten");
         return;
      }
      Print(">>> TRADE OEFFNEN: BUY (#", (buys + 1), " von ", Max_Trades_Pro_Richtung, ")");
      TradeOeffnen(OP_BUY);
      g_letzter_buy_zeit = TimeCurrent();
   }
   //--- SELL OEFFNEN ------------------------------------------------
   else if(signal == "SELL")
   {
      // V6.6: Im UMDREHEN-Modus max 1 Trade pro Richtung
      if(Modus_Umdrehen == Ja && sells >= 1)
      {
         Print("SELL ignoriert - schon ", sells, " SELL offen (UMDREHEN: nur 1 pro Richtung)");
         return;
      }
      // V6.4: Im UMDREHEN-Modus erst alle BUY schliessen
      if(Modus_Umdrehen == Ja && buys > 0)
      {
         Print(">>> UMDREHEN: Schliesse alle ", buys, " BUY-Trades");
         SchliesseAlleTrades(OP_BUY);
         g_letzter_buy_zeit = 0;
         buys = 0;  // wurden ja gerade geschlossen
      }
      if(sells >= Max_Trades_Pro_Richtung)
      {
         Print("SELL ignoriert - Max erreicht (", sells, "/", Max_Trades_Pro_Richtung, ")");
         return;
      }
      int sek_seit_letztem = (g_letzter_sell_zeit > 0) ? (int)(TimeCurrent() - g_letzter_sell_zeit) : 999999;
      if(sek_seit_letztem < Min_Sekunden_Zw_Trades)
      {
         int rest = Min_Sekunden_Zw_Trades - sek_seit_letztem;
         Print("SELL Cooldown - noch ", rest, "s warten");
         return;
      }
      Print(">>> TRADE OEFFNEN: SELL (#", (sells + 1), " von ", Max_Trades_Pro_Richtung, ")");
      TradeOeffnen(OP_SELL);
      g_letzter_sell_zeit = TimeCurrent();
   }
   //--- ALLE BUY SCHLIESSEN -----------------------------------------
   else if(signal == "CLOSE_BUY")
   {
      if(buys > 0)
      {
         Print(">>> SCHLIESSE ALLE BUY-Trades (", buys, " Stueck)");
         SchliesseAlleTrades(OP_BUY);
         g_letzter_buy_zeit = 0;  // Cooldown zuruecksetzen
      }
      else
         Print("CLOSE_BUY ignoriert - keine BUY-Trades offen");
   }
   //--- ALLE SELL SCHLIESSEN ----------------------------------------
   else if(signal == "CLOSE_SELL")
   {
      if(sells > 0)
      {
         Print(">>> SCHLIESSE ALLE SELL-Trades (", sells, " Stueck)");
         SchliesseAlleTrades(OP_SELL);
         g_letzter_sell_zeit = 0;  // Cooldown zuruecksetzen
      }
      else
         Print("CLOSE_SELL ignoriert - keine SELL-Trades offen");
   }
}

void OnTick() { }

//+------------------------------------------------------------------+
//| SCHWARZE MASKE (BMP)                                             |
//+------------------------------------------------------------------+
void MaskePlatzieren()
{
   string name = "GOLDY_MASKE";
   if(ObjectFind(name) == -1)
      ObjectCreate(name, OBJ_BITMAP_LABEL, 0, 0, 0);

   ObjectSet(name, OBJPROP_XDISTANCE, Maske_X);
   ObjectSet(name, OBJPROP_YDISTANCE, Maske_Y);
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetString(0, name, OBJPROP_BMPFILE, "\\Images\\" + Maske_Datei);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_BACK, false);
   ChartRedraw(0);
   Print("Schwarze Maske platziert: ", Maske_Datei, " bei X=", Maske_X, " Y=", Maske_Y);
}

//+------------------------------------------------------------------+
//| TRADE FUNKTIONEN (V6.2: Multi-Trade / Pyramiding)                |
//+------------------------------------------------------------------+
// Zaehlt alle offenen Trades eines bestimmten Typs (OP_BUY oder OP_SELL)
// nur fuer diese Magic-Number und dieses Symbol.
int ZaehleOffeneTrades(int typ)
{
   int anzahl = 0;
   for(int i = 0; i < OrdersTotal(); i++)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(OrderMagicNumber() != Magic) continue;
      if(OrderSymbol() != Symbol()) continue;
      if(OrderType() == typ) anzahl++;
   }
   return anzahl;
}

void TradeOeffnen(int typ)
{
   double preis = (typ == OP_BUY) ? Ask : Bid;
   int ticket = OrderSend(Symbol(), typ, Lot, preis, 10, 0, 0, "GOLDY_V6", Magic, 0, clrNONE);

   if(ticket > 0)
   {
      string richtung = (typ == OP_BUY) ? "BUY" : "SELL";
      Print("TRADE GEOEFFNET: ", richtung, " @ ", DoubleToStr(preis, Digits), " Ticket: ", ticket);

      // Telegram Nachricht
      SendeNeuerTrade(typ, preis);
   }
   else
      Print("TRADE FEHLER: ", GetLastError());
}

// Schliesst ALLE offenen Trades eines bestimmten Typs (BUY oder SELL).
// V6.2: Wird durch CLOSE_BUY / CLOSE_SELL Signale ausgeloest.
void SchliesseAlleTrades(int typ)
{
   // Rueckwaerts iterieren weil sich der Index aendert wenn Orders geschlossen werden
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(OrderMagicNumber() != Magic) continue;
      if(OrderSymbol() != Symbol()) continue;
      if(OrderType() != typ) continue;

      double preis = (typ == OP_BUY) ? Bid : Ask;
      double open_preis = OrderOpenPrice();
      datetime open_zeit = OrderOpenTime();
      int ticket = OrderTicket();

      if(OrderClose(ticket, OrderLots(), preis, 10, clrNONE))
      {
         double profit = OrderProfit() + OrderSwap() + OrderCommission();
         string richtung = (typ == OP_BUY) ? "BUY" : "SELL";
         bool ist_win = (profit > 0);
         Print("TRADE GESCHLOSSEN: ", richtung, " Ticket: ", ticket, " P/L: ", DoubleToStr(profit, 2));

         // Telegram Nachricht (pro geschlossenem Trade einzeln)
         SendeTradeGeschlossen(typ, open_preis, preis, profit, open_zeit, ist_win);
      }
      else
         Print("CLOSE FEHLER fuer Ticket ", ticket, ": ", GetLastError());
   }
}

//+------------------------------------------------------------------+
//| TELEGRAM NACHRICHTEN                                             |
//+------------------------------------------------------------------+
void SendeNeuerTrade(int typ, double preis)
{
   string nl = CharToString(10);
   string richtung = (typ == OP_BUY) ? "BUY" : "SELL";

   // 1. Bild senden
   if(NT_Bild_Senden == Ja)
      SendeFotoURL(NewTrade_URL, "", Chat_ID);

   // 2. Text-Nachricht
   string msg = "NEUER TRADE" + nl;
   if(NT_Richtung == Ja) msg += richtung + nl;
   if(NT_Waehrung == Ja) msg += Symbol() + nl;
   if(NT_Preis == Ja) msg += "Entry: " + DoubleToStr(preis, Digits) + nl;
   if(NT_Datum == Ja) msg += "Datum: " + TimeToStr(TimeLocal(), TIME_DATE) + nl;
   if(NT_Uhrzeit == Ja) msg += "Uhrzeit: " + TimeToStr(TimeLocal(), TIME_SECONDS) + nl;
   if(NT_Lot == Ja) msg += "Lot: " + DoubleToStr(Lot, 2) + nl;

   SendeText(msg, Chat_ID);
}

void SendeTradeGeschlossen(int typ, double open_preis, double close_preis, double profit, datetime open_zeit, bool ist_win)
{
   string nl = CharToString(10);
   string richtung = (typ == OP_BUY) ? "BUY" : "SELL";
   int dauer_min = (int)((TimeCurrent() - open_zeit) / 60);

   // 1. Bild senden
   if(CT_Bild_Senden == Ja)
      SendeFotoURL(CloseTrade_URL, "", Chat_ID);

   // 2. Text-Nachricht
   string msg = "TRADE GESCHLOSSEN" + nl;
   if(CT_Waehrung == Ja) msg += Symbol() + nl;
   if(CT_Entry == Ja) msg += "Entry: " + DoubleToStr(open_preis, Digits) + nl;
   if(CT_Close == Ja) msg += "Close: " + DoubleToStr(close_preis, Digits) + nl;
   if(CT_PL == Ja) msg += "P/L: " + DoubleToStr(profit, 2) + nl;
   if(CT_Dauer == Ja) msg += "Dauer: " + IntegerToString(dauer_min) + " min" + nl;
   if(CT_Datum == Ja) msg += "Datum: " + TimeToStr(TimeLocal(), TIME_DATE) + nl;
   if(CT_Uhrzeit == Ja) msg += "Uhrzeit: " + TimeToStr(TimeLocal(), TIME_SECONDS) + nl;
   if(CT_Lot == Ja) msg += "Lot: " + DoubleToStr(Lot, 2) + nl;
   msg += "Ergebnis: " + (ist_win ? "WIN" : "LOSS");

   SendeText(msg, Chat_ID);

   // 3. Win/Loss Bild
   if(ist_win && Win_Bild == Ja) SendeFotoURL(Winning_URL, "", Chat_ID);
   if(!ist_win && Loss_Bild == Ja) SendeFotoURL(Loss_URL, "", Chat_ID);
}

//+------------------------------------------------------------------+
//| TELEGRAM SENDEN                                                  |
//+------------------------------------------------------------------+
bool SendeFotoURL(string foto_url, string caption, string chat_id)
{
   if(StringLen(Bot_Token) < 10 || StringLen(chat_id) < 5) return false;
   string url = "https://api.telegram.org/bot" + Bot_Token + "/sendPhoto";
   string data = "chat_id=" + chat_id + "&photo=" + foto_url;
   if(StringLen(caption) > 0) data += "&caption=" + UrlEnc(caption);
   uchar req[], res[]; string h = "";
   int len = StringLen(data); ArrayResize(req, len);
   StringToCharArray(data, req, 0, len, CP_UTF8);
   int code = WebRequest("POST", url, "Content-Type: application/x-www-form-urlencoded", 10000, req, res, h);
   return(code == 200);
}

bool SendeText(string text, string chat_id)
{
   if(StringLen(Bot_Token) < 10 || StringLen(chat_id) < 5) return false;
   string url = "https://api.telegram.org/bot" + Bot_Token + "/sendMessage";
   string data = "chat_id=" + chat_id + "&text=" + UrlEnc(text);
   uchar req[], res[]; string h = "";
   int len = StringLen(data); ArrayResize(req, len);
   StringToCharArray(data, req, 0, len, CP_UTF8);
   int code = WebRequest("POST", url, "Content-Type: application/x-www-form-urlencoded", 5000, req, res, h);
   return(code == 200);
}

//+------------------------------------------------------------------+
//| KI-ANALYSE                                                       |
//+------------------------------------------------------------------+
string KI_Analyse()
{
   // V6.3: Bild bleibt liegen wenn Debug aktiv -> klarer Dateiname
   string datei = (Debug_Bild_Speichern == Ja) ? "goldy_v6_letztes_bild.png" : "goldy_v6_temp.png";

   //==== NEU IN V6.1: ChartScreenShot statt WindowScreenShot =========
   // ChartScreenShot mit ALIGN_RIGHT rendert nur die letzten Bars,
   // wenn die angegebene Breite kleiner ist als noetig waere fuer alle Bars.
   // Dadurch werden alte Symbole gar nicht erst ins Bild gezeichnet.
   bool ok;
   if(Crop_Aktiv == Ja)
   {
      ok = ChartScreenShot(0, datei, Crop_Breite_Pixel, Crop_Hoehe_Pixel, ALIGN_RIGHT);
      if(ok)
         Print("Screenshot CROP: ", Crop_Breite_Pixel, "x", Crop_Hoehe_Pixel, " (rechtsbuendig)");
   }
   else
   {
      ok = ChartScreenShot(0, datei, 1280, 800, ALIGN_RIGHT);
      if(ok)
         Print("Screenshot FULL: 1280x800");
   }

   if(!ok)
   { Print("Screenshot FEHLER: ", GetLastError()); return "NONE"; }
   //=====================================================================

   uchar bild[];
   int fh = FileOpen(datei, FILE_READ | FILE_BIN);
   if(fh == INVALID_HANDLE) return "NONE";
   int size = (int)FileSize(fh);
   ArrayResize(bild, size);
   FileReadArray(fh, bild, 0, size);
   FileClose(fh);

   // V6.3: Datei nur loeschen wenn Debug AUS ist
   if(Debug_Bild_Speichern == Nein)
      FileDelete(datei);

   string b64 = Base64(bild);
   string content = OpenAI_Senden(b64);
   if(StringLen(content) == 0) return "NONE";

   string signal = JsonWert(content, "signal");
   string conf = JsonWert(content, "confidence");
   string reason = JsonWert(content, "reason");

   Print("KI: signal=", signal, " conf=", conf, " | ", reason);

   if(conf != "high") return "NONE";
   if(signal == "BUY" || signal == "SELL" || signal == "CLOSE_BUY" || signal == "CLOSE_SELL")
      return signal;
   return "NONE";
}

//+------------------------------------------------------------------+
//| OPENAI API                                                       |
//+------------------------------------------------------------------+
string OpenAI_Senden(string bild_b64)
{
   string nl = CharToString(10); string dq = CharToString(34); string bs = CharToString(92);
   string sys = EscJson(g_prompt);
   string usr = EscJson("Analysiere das Bild. Antworte NUR mit JSON: {" + dq + "signal" + dq + ":" + dq + "BUY/SELL/CLOSE_BUY/CLOSE_SELL/NONE" + dq + "," + dq + "confidence" + dq + ":" + dq + "high/medium/low" + dq + "," + dq + "reason" + dq + ":" + dq + "..." + dq + "}");

   // V6.5: Modell und Bild-Detail aus Input
   string body = "{" + dq + "model" + dq + ":" + dq + KI_Modell + dq + ",";
   body += dq + "max_tokens" + dq + ":150," + dq + "temperature" + dq + ":0.1,";
   body += dq + "messages" + dq + ":[";
   body += "{" + dq + "role" + dq + ":" + dq + "system" + dq + "," + dq + "content" + dq + ":" + dq + sys + dq + "},";
   body += "{" + dq + "role" + dq + ":" + dq + "user" + dq + "," + dq + "content" + dq + ":[";
   body += "{" + dq + "type" + dq + ":" + dq + "text" + dq + "," + dq + "text" + dq + ":" + dq + usr + dq + "},";
   body += "{" + dq + "type" + dq + ":" + dq + "image_url" + dq + "," + dq + "image_url" + dq + ":{";
   body += dq + "url" + dq + ":" + dq + "data:image/png;base64," + bild_b64 + dq + ",";
   body += dq + "detail" + dq + ":" + dq + Bild_Detail + dq;
   body += "}}]}]}";

   string headers = "Content-Type: application/json" + CharToString(13) + nl + "Authorization: Bearer " + API_Key + CharToString(13) + nl;
   char post[]; StringToCharArray(body, post, 0, StringLen(body), CP_UTF8);
   char res[]; string res_h;
   int code = WebRequest("POST", "https://api.openai.com/v1/chat/completions", headers, API_Timeout * 1000, post, res, res_h);
   if(code != 200) { Print("OpenAI HTTP ", code); return ""; }

   string resp = CharArrayToString(res, 0, -1, CP_UTF8);
   int cp = StringFind(resp, "choices"); if(cp < 0) return "";
   cp = StringFind(resp, "content", cp); if(cp < 0) return "";
   int col = StringFind(resp, ":", cp); if(col < 0) return "";
   int vs = col + 1;
   while(vs < StringLen(resp) && StringGetCharacter(resp, vs) <= 32) vs++;
   if(StringGetCharacter(resp, vs) != 34) return "";
   vs++; int ve = vs;
   while(ve < StringLen(resp)) { if(StringGetCharacter(resp, ve) == 34 && StringGetCharacter(resp, ve-1) != 92) break; ve++; }
   string content = StringSubstr(resp, vs, ve - vs);
   StringReplace(content, bs + dq, dq); StringReplace(content, bs + "n", nl);
   return content;
}

//+------------------------------------------------------------------+
//| HILFSFUNKTIONEN                                                  |
//+------------------------------------------------------------------+
string PromptLaden(string pfad)
{
   int fh = FileOpen(pfad, FILE_READ | FILE_TXT | FILE_COMMON);
   if(fh == INVALID_HANDLE) return "";
   string r = "";
   while(!FileIsEnding(fh)) { if(StringLen(r) > 0) r += CharToString(10); r += FileReadString(fh); }
   FileClose(fh); return r;
}

string Base64(const uchar &d[])
{
   string b = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
   string r = ""; int l = ArraySize(d);
   for(int i = 0; i < l; i += 3)
   { uint b1=d[i],b2=(i+1<l)?d[i+1]:0,b3=(i+2<l)?d[i+2]:0;
   r+=StringSubstr(b,(int)((b1>>2)&0x3F),1); r+=StringSubstr(b,(int)(((b1<<4)|(b2>>4))&0x3F),1);
   r+=(i+1<l)?StringSubstr(b,(int)(((b2<<2)|(b3>>6))&0x3F),1):"=";
   r+=(i+2<l)?StringSubstr(b,(int)(b3&0x3F),1):"="; } return r;
}

string EscJson(string t)
{ string r=t; StringReplace(r,CharToString(92),CharToString(92)+CharToString(92));
StringReplace(r,CharToString(34),CharToString(92)+CharToString(34));
StringReplace(r,CharToString(10),CharToString(92)+"n"); StringReplace(r,CharToString(13),CharToString(92)+"r"); return r; }

string JsonWert(string json, string key)
{ string dq=CharToString(34); int p=StringFind(json,dq+key+dq); if(p<0) return "";
p=StringFind(json,":",p); if(p<0) return ""; p++;
while(p<StringLen(json)&&StringGetCharacter(json,p)<=32) p++;
if(StringGetCharacter(json,p)==34){ p++; int e=p;
while(e<StringLen(json)){if(StringGetCharacter(json,e)==34&&StringGetCharacter(json,e-1)!=92)break;e++;}
return StringSubstr(json,p,e-p); }
int e2=p; while(e2<StringLen(json)&&StringGetCharacter(json,e2)!=44&&StringGetCharacter(json,e2)!=125) e2++;
return StringSubstr(json,p,e2-p); }

string UrlEnc(string t)
{ string r=""; uchar b[]; int l=StringToCharArray(t,b,0,WHOLE_ARRAY,CP_UTF8)-1;
for(int i=0;i<l;i++){uchar c=b[i];if((c>=65&&c<=90)||(c>=97&&c<=122)||(c>=48&&c<=57)||c==45||c==95||c==46||c==126)r+=CharToString(c);else r+=StringFormat("%%%02X",c);}return r;}
//+------------------------------------------------------------------+
