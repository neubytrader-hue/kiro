//+------------------------------------------------------------------+
//|                                    Goldy_AI_Trader_V7_0.mq4      |
//|                                  GOLDY AI TRADER V 7.0           |
//|                                  Copyright 2026, Alex            |
//+------------------------------------------------------------------+
//|  CHANGES V7.0 (vs V6.6):                                          |
//|  - GPT-Modell als DROPDOWN (8 Modelle)                            |
//|  - LIVE-SCREENSHOT BRIDGE zum GOLDY Screenshot V 2.0              |
//|  - KONTO-Modul: Konto-Typ (Pro_Cent/Pro/ECN/Prime), Waehrung      |
//|    ($/EUR), Konto-Bezeichnung -> Cent-Konten werden korrekt in    |
//|    USD/EUR umgerechnet in Telegram-Nachrichten                    |
//|  - TAGESBERICHT (einstellbare Uhrzeit, Mo-Fr / Mo-So)             |
//|  - WOCHENBERICHT (einstellbare Uhrzeit, Fr / So / Fr+So)          |
//|  - STARTUP-Bild beim EA-Start                                     |
//|  - TICKETS-PERSISTENZ (.dat-Dateien) -> kein Doppel-Send nach     |
//|    Neustart                                                       |
//|  - INVESTMENT-Basis-Berechnung fuer Renditen-Prozente             |
//|  - NEUE Reihenfolge bei TRADE GESCHLOSSEN:                        |
//|    1.GESCHLOSSEN 2.Symbol 3.Lot 4.Datum 5.Uhrzeit 6.Entry         |
//|    7.Close 8.Dauer 9.Ergebnis 10.P/L                              |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Alex"
#property version   "7.00"
#property description "GOLDY AI TRADER V 7.0 - Screenshot-Bridge + Berichte + Konto-Modul"
#property strict

//+------------------------------------------------------------------+
//| ENUMS                                                            |
//+------------------------------------------------------------------+
enum ENUM_JN { Nein = 0, Ja = 1 };

// V7.0: GPT-Modell-Auswahl (Dropdown im Input-Fenster)
enum ENUM_GPT_MODEL
{
   GPT_4o,           // gpt-4o
   GPT_4o_mini,      // gpt-4o-mini
   GPT_4_turbo,      // gpt-4-turbo
   GPT_4_1,          // gpt-4.1
   GPT_4_1_mini,     // gpt-4.1-mini
   GPT_o1,           // o1
   GPT_o1_mini,      // o1-mini
   GPT_o3_mini       // o3-mini
};

// V7.0: Konto-Typ (Cent-Konto wird automatisch /100 gerechnet)
enum ENUM_KONTO_TYP { Pro_Cent = 0, Pro = 1, ECN = 2, Prime = 3 };

// V7.0: Waehrungssymbol fuer Telegram-Nachrichten
enum ENUM_WAEHRUNG { WAHR_USD = 0, WAHR_EUR = 1 };

// V7.0: An welchen Wochentagen Tagesbericht gesendet wird
enum ENUM_TAGES_BERICHT_TAGE { Mo_Fr = 0, Mo_So = 1 };

// V7.0: An welchen Tagen Wochenbericht gesendet wird
enum ENUM_WOCHEN_BERICHT_TAGE { Nur_Freitag = 0, Nur_Sonntag = 1, Fr_Und_So = 2 };

#define OP_BALANCE 6
#define MSG_SEP    "...\n"

//+------------------------------------------------------------------+
//| EINGABE-PARAMETER                                                |
//+------------------------------------------------------------------+
input string         __API_Header       = "==== OPENAI ====";
input string         API_Key            = "DEIN_KEY_HIER";
input int            Analyse_Intervall  = 60;
input int            API_Timeout        = 30;

// V7.0: KI-Modell als Dropdown
input ENUM_GPT_MODEL KI_Modell          = GPT_4o_mini;
input string         Bild_Detail        = "high";  // low oder high

input string   __Telegram_Header  = "==== TELEGRAM ====";
input string   Bot_Token          = "DEIN_TOKEN";
input string   Chat_ID            = "";
input string   Erlaubte_ID        = "";

//==== V7.0 NEU: KONTO ============================================
input string         __Konto_Header     = "==== KONTO ====";
input string         Konto_Bezeichnung  = "MT4 #1 - GOLDY V7";
input ENUM_KONTO_TYP Konto_Typ          = Pro_Cent;
input ENUM_WAEHRUNG  Waehrungssymbol    = WAHR_USD;
//=================================================================

input string   __Trading_Header   = "==== TRADING ====";
input double   Lot                = 0.10;
input int      Magic              = 1001;

input string   __Multi_Header     = "==== MEHRERE TRADES (Pyramiding) ====";
input int      Max_Trades_Pro_Richtung = 3;
input int      Min_Sekunden_Zw_Trades  = 120;

input string   __Umdrehen_Header  = "==== UMDREHEN-MODUS (fuer Sterne-Indikator) ====";
input ENUM_JN  Modus_Umdrehen     = Nein;

input string   __Crop_Header      = "==== SCREENSHOT-CROP (KI sieht nur rechte Bars) ====";
input ENUM_JN  Crop_Aktiv         = Ja;
input int      Crop_Breite_Pixel  = 350;
input int      Crop_Hoehe_Pixel   = 800;

input string   __Debug_Header     = "==== DEBUG ====";
input ENUM_JN  Debug_Bild_Speichern = Ja;

input string   __Maske_Header     = "==== SCHWARZE MASKE (BMP) ====";
input ENUM_JN  Maske_Aktiv        = Nein;
input string   Maske_Datei        = "black_mask.bmp";
input int      Maske_X            = 0;
input int      Maske_Y            = 0;

input string   __Prompt_Header    = "==== KI ====";
input string   Prompt_Datei       = "Goldy\\prompt_mt4_1min.txt";

//==== V7.0: BRIDGE ZUM SCREENSHOT-EA ==============================
input string   __Bridge_Header          = "==== SCREENSHOT-EA BRIDGE ====";
input ENUM_JN  Screenshot_Aktiv         = Ja;
input ENUM_JN  Screenshot_Bei_Open      = Ja;
input ENUM_JN  Screenshot_Bei_Close     = Ja;
input string   Bridge_Request_Datei     = "Goldy_Shared\\screenshot_request.txt";
input string   Bridge_Done_Datei        = "Goldy_Shared\\screenshot_done.txt";
input int      Bridge_Max_Warten_Sek    = 8;
input int      Bridge_Poll_ms           = 200;
//==================================================================

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
input ENUM_JN  CT_Lot             = Ja;
input ENUM_JN  CT_Datum           = Ja;
input ENUM_JN  CT_Uhrzeit         = Ja;
input ENUM_JN  CT_Entry           = Ja;
input ENUM_JN  CT_Close           = Ja;
input ENUM_JN  CT_Dauer           = Ja;
input ENUM_JN  CT_PL              = Ja;

input string   __WL_Header        = "==== NACHRICHT: WIN / LOSS ====";
input ENUM_JN  Win_Bild           = Ja;
input ENUM_JN  Loss_Bild          = Ja;

//==== V7.0 NEU: TAGESBERICHT =====================================
input string                  __Tag_Header           = "==== TAGESBERICHT ====";
input bool                    Tagesbericht_Aktiv     = true;
input string                  Tagesbericht_Uhrzeit   = "21:58";
input ENUM_TAGES_BERICHT_TAGE Tagesbericht_Wochentage = Mo_Fr;
//==================================================================

//==== V7.0 NEU: WOCHENBERICHT ====================================
input string                   __Woche_Header        = "==== WOCHENBERICHT ====";
input bool                     Wochenbericht_Aktiv   = true;
input string                   Wochenbericht_Uhrzeit = "21:59";
input ENUM_WOCHEN_BERICHT_TAGE Wochenbericht_Tag     = Nur_Freitag;
//==================================================================

//+------------------------------------------------------------------+
//| BILD-URLS                                                        |
//+------------------------------------------------------------------+
string NewTrade_URL     = "https://i.postimg.cc/tJ5wCt20/new-trade.jpg";
string Winning_URL      = "https://i.postimg.cc/pLy4Rjjg/winning.jpg";
string Loss_URL         = "https://i.postimg.cc/J0PYW7zr/loss.jpg";
string CloseTrade_URL   = "https://i.postimg.cc/Xv0PpD9j/close-trade.jpg";
string Startup_URL      = "https://i.postimg.cc/W4FB6Zbd/startup.jpg";
string DayReport_URL    = "https://i.postimg.cc/tJCDD0tx/day-report.jpg";
string WeeklyReport_URL = "https://i.postimg.cc/c4CXnSJC/weekly-report.jpg";

//+------------------------------------------------------------------+
//| GLOBALE VARIABLEN                                                |
//+------------------------------------------------------------------+
string   g_prompt = "";
string   g_letztes_signal = "NONE";
uint     g_letzte_analyse = 0;
datetime g_letzter_buy_zeit  = 0;
datetime g_letzter_sell_zeit = 0;

// V7.0: Konto/Berichte/Persistenz
string   g_Waehrungssymbol = "$";
string   g_FileSuffix      = "";
string   TPR_sentOpen      = "";   // Liste der bereits gemeldeten Open-Tickets
string   TPR_sentClosed    = "";   // Liste der bereits gemeldeten Close-Tickets
double   equityStartTag    = 0;
double   equityStartWoche  = 0;
double   maxEquityHeute    = 0;
double   minEquityHeute    = 0;
datetime letzterBerichtTag = 0;
datetime wocheStartZeit    = 0;
bool     berichtGesendetHeute  = false;
bool     wochenberichtGesendet = false;
bool     wocheResetErledigt    = false;
datetime EA_StartZeit          = 0;

//+------------------------------------------------------------------+
//| V7.0: GPT-Modell-Mapping (Enum -> API-String)                    |
//+------------------------------------------------------------------+
string GPTModelToString(ENUM_GPT_MODEL m)
{
   switch(m)
   {
      case GPT_4o:        return "gpt-4o";
      case GPT_4o_mini:   return "gpt-4o-mini";
      case GPT_4_turbo:   return "gpt-4-turbo";
      case GPT_4_1:       return "gpt-4.1";
      case GPT_4_1_mini:  return "gpt-4.1-mini";
      case GPT_o1:        return "o1";
      case GPT_o1_mini:   return "o1-mini";
      case GPT_o3_mini:   return "o3-mini";
   }
   return "gpt-4o-mini";
}

//+------------------------------------------------------------------+
//| V7.0: KONTO-/GELD-HILFSFUNKTIONEN (1:1 aus Goldy Reporter)       |
//+------------------------------------------------------------------+
// Rechnet Cent-Konto-Werte automatisch in USD/EUR um und macht "+" davor
string FormatGeld(double wert)
{
   double val = (Konto_Typ == Pro_Cent) ? wert / 100.0 : wert;
   string sign = (val >= 0) ? "+" : "";
   return sign + DoubleToString(val, 2);
}

// Summiert alle Einzahlungen aus der History (OP_BALANCE) als Investment-Basis
double BerechneInvestmentBasis()
{
   double basis = 0;
   int tot = OrdersHistoryTotal();
   for(int k = 0; k < tot; k++)
   {
      if(OrderSelect(k, SELECT_BY_POS, MODE_HISTORY))
         if(OrderType() == OP_BALANCE) basis += OrderProfit();
   }
   double result = (basis > 0 ? basis : AccountBalance());
   if(Konto_Typ == Pro_Cent) result = result / 100.0;
   return result;
}

// Prozentrendite vom Investment
string FormatRendite(double profit, double basis)
{
   if(basis <= 0) return "";
   double profitInUsd = (Konto_Typ == Pro_Cent) ? profit / 100.0 : profit;
   double pct = (profitInUsd / basis) * 100.0;
   return (pct >= 0 ? "+" : "") + DoubleToString(pct, 3) + "%";
}

//+------------------------------------------------------------------+
//| V7.0: TICKET-LISTEN-HILFSFUNKTIONEN (Persistenz-Helper)          |
//+------------------------------------------------------------------+
bool IstInListe(string liste, string ticket)
{
   if(StringLen(liste) == 0) return false;
   return(StringFind("," + liste, "," + ticket + ",") >= 0);
}

string FuegeZuListe(string liste, string ticket)
{
   if(!IstInListe(liste, ticket)) liste += ticket + ",";
   return liste;
}

void LadeGesendeteTickets()
{
   TPR_sentOpen = "";
   int h1 = FileOpen(StringFormat("goldy%s_open.dat", g_FileSuffix), FILE_BIN | FILE_READ);
   if(h1 != INVALID_HANDLE)
   {
      TPR_sentOpen = FileReadString(h1, -1);
      FileClose(h1);
   }
   if(StringLen(TPR_sentOpen) > 0 &&
      StringSubstr(TPR_sentOpen, StringLen(TPR_sentOpen)-1, 1) != ",")
      TPR_sentOpen += ",";

   TPR_sentClosed = "";
   int h2 = FileOpen(StringFormat("goldy%s_closed.dat", g_FileSuffix), FILE_BIN | FILE_READ);
   if(h2 != INVALID_HANDLE)
   {
      TPR_sentClosed = FileReadString(h2, -1);
      FileClose(h2);
   }
   if(StringLen(TPR_sentClosed) > 0 &&
      StringSubstr(TPR_sentClosed, StringLen(TPR_sentClosed)-1, 1) != ",")
      TPR_sentClosed += ",";
}

void SpeichereGesendeteTickets()
{
   int h1 = FileOpen(StringFormat("goldy%s_open.dat", g_FileSuffix), FILE_BIN | FILE_WRITE);
   if(h1 != INVALID_HANDLE)
   {
      FileWriteString(h1, TPR_sentOpen, StringLen(TPR_sentOpen));
      FileClose(h1);
   }
   int h2 = FileOpen(StringFormat("goldy%s_closed.dat", g_FileSuffix), FILE_BIN | FILE_WRITE);
   if(h2 != INVALID_HANDLE)
   {
      FileWriteString(h2, TPR_sentClosed, StringLen(TPR_sentClosed));
      FileClose(h2);
   }
}

// Beim Start: alle alten Trades als "schon gemeldet" markieren -> kein Spam
void VormerkenAlleHistorischenTrades()
{
   int vorgemerkt = 0;
   int tot = OrdersHistoryTotal();
   for(int k = 0; k < tot; k++)
   {
      if(OrderSelect(k, SELECT_BY_POS, MODE_HISTORY))
      {
         int ot = OrderType();
         if(ot != OP_BUY && ot != OP_SELL) continue;
         string t = IntegerToString(OrderTicket());
         if(!IstInListe(TPR_sentClosed, t))
         {
            TPR_sentClosed += t + ",";
            vorgemerkt++;
         }
      }
   }
   int totOpen = OrdersTotal();
   for(int k = 0; k < totOpen; k++)
   {
      if(OrderSelect(k, SELECT_BY_POS, MODE_TRADES))
      {
         int ot = OrderType();
         if(ot != OP_BUY && ot != OP_SELL) continue;
         string t = IntegerToString(OrderTicket());
         if(!IstInListe(TPR_sentOpen, t))
         {
            TPR_sentOpen += t + ",";
            vorgemerkt++;
         }
      }
   }
   if(vorgemerkt > 0)
   {
      SpeichereGesendeteTickets();
      Print("Tickets vorgemerkt (kein Doppel-Send): ", vorgemerkt);
   }
}

//+------------------------------------------------------------------+
//| V7.0: TAGES-/WOCHEN-LOGIK (1:1 aus Goldy Reporter)               |
//+------------------------------------------------------------------+
// Setzt Tages-Werte zurueck (Equity, Berichts-Flag, Wochen-Reset bei Mo)
void ResetTagesStatistik()
{
   equityStartTag       = AccountEquity();
   maxEquityHeute       = equityStartTag;
   minEquityHeute       = equityStartTag;
   berichtGesendetHeute = false;

   int dow = TimeDayOfWeek(TimeLocal());
   if(dow == 0) dow = 7;
   if(dow == 1 && !wocheResetErledigt)
   {
      equityStartWoche = AccountEquity();
      MqlDateTime dtMo;
      TimeToStruct(TimeLocal(), dtMo);
      dtMo.hour = 0; dtMo.min = 0; dtMo.sec = 0;
      wocheStartZeit          = StructToTime(dtMo);
      wocheResetErledigt      = true;
      wochenberichtGesendet   = false;
   }
   if(dow == 2) wocheResetErledigt = false;
}

// Liefert "Mo, 13.06. OK\nDi, 14.06. OK\n..." fuer Wochenbericht-Vorschau
string GetHandelstageNaechsteWoche()
{
   datetime jetzt = TimeLocal();
   int wt = TimeDayOfWeek(jetzt);
   if(wt == 0) wt = 7;
   int tb = (wt == 1) ? 7 : (8 - wt);
   datetime mo = jetzt + (tb * 86400);
   string t[5] = {"Mo", "Di", "Mi", "Do", "Fr"};
   string r = "";
   for(int k = 0; k < 5; k++)
   {
      datetime tg = mo + (k * 86400);
      r += t[k] + ", " + StringFormat("%02d.%02d.", TimeDay(tg), TimeMonth(tg)) + " OK\n";
   }
   return r;
}

void PruefeTagesbericht()
{
   if(!Tagesbericht_Aktiv) return;

   if(TimeDay(TimeLocal()) != TimeDay(letzterBerichtTag))
   {
      ResetTagesStatistik();
      letzterBerichtTag = TimeLocal();
   }
   if(berichtGesendetHeute) return;

   if(StringLen(Tagesbericht_Uhrzeit) < 5) return;
   int targetH = (int)StringToInteger(StringSubstr(Tagesbericht_Uhrzeit, 0, 2));
   int targetM = (int)StringToInteger(StringSubstr(Tagesbericht_Uhrzeit, 3, 2));
   int bh = TimeHour(TimeLocal());
   int dayOfWeek = TimeDayOfWeek(TimeLocal());

   bool tagesberichtErlaubt = false;
   if(Tagesbericht_Wochentage == Mo_So) tagesberichtErlaubt = true;
   else if(Tagesbericht_Wochentage == Mo_Fr && dayOfWeek >= 1 && dayOfWeek <= 5)
      tagesberichtErlaubt = true;

   if(bh == targetH && TimeMinute(TimeLocal()) == targetM && tagesberichtErlaubt)
   {
      berichtGesendetHeute = true;
      double basis = BerechneInvestmentBasis();
      double tagesProfit = 0, wochenProfit = 0, gesamtProfit = 0;
      int heuteWin = 0, heuteLoss = 0;
      datetime heuteStart = StringToTime(TimeToString(TimeLocal(), TIME_DATE) + " 00:00");

      // ALLE Trades auf dem Symbol zaehlen (keine Magic-Filterung - wie im Reporter)
      for(int k = OrdersHistoryTotal() - 1; k >= 0; k--)
      {
         if(OrderSelect(k, SELECT_BY_POS, MODE_HISTORY) && OrderSymbol() == Symbol())
         {
            double profit = OrderProfit() + OrderSwap() + OrderCommission();
            datetime ct = OrderCloseTime();
            gesamtProfit += profit;
            if(ct >= wocheStartZeit) wochenProfit += profit;
            if(ct >= heuteStart)
            {
               tagesProfit += profit;
               if(profit > 0) heuteWin++;
               else if(profit < 0) heuteLoss++;
            }
         }
      }

      string nl = CharToString(10);
      string msg = "TAGESBERICHT" + nl + Konto_Bezeichnung + nl + MSG_SEP;
      msg += "Tages P/L: "    + FormatGeld(tagesProfit)  + " " + g_Waehrungssymbol + nl;
      msg += "Tages Rendite: " + FormatRendite(tagesProfit, basis) + " vom Investment" + nl;
      msg += "Wochen P/L: "   + FormatGeld(wochenProfit) + " " + g_Waehrungssymbol + nl;
      msg += "Wochen Rendite: " + FormatRendite(wochenProfit, basis) + " vom Investment" + nl;
      msg += "Gesamt P/L: "   + FormatGeld(gesamtProfit) + " " + g_Waehrungssymbol + nl;
      msg += "Gesamt Rendite: " + FormatRendite(gesamtProfit, basis) + " vom Investment" + nl;
      msg += MSG_SEP;
      msg += "Trades heute: " + IntegerToString(heuteWin + heuteLoss)
           + " (" + IntegerToString(heuteWin) + "W/" + IntegerToString(heuteLoss) + "L)" + nl;
      msg += "Aktuelle Equity: " + FormatGeld(AccountEquity()) + " " + g_Waehrungssymbol;

      SendeFotoURL(DayReport_URL, "", Chat_ID);
      SendeText(msg, Chat_ID);
      Print("Tagesbericht gesendet.");
   }
}

void PruefeWochenbericht()
{
   if(!Wochenbericht_Aktiv) return;
   if(StringLen(Wochenbericht_Uhrzeit) < 5) return;

   int cd = TimeDayOfWeek(TimeLocal());
   int bh = TimeHour(TimeLocal());
   int bm = TimeMinute(TimeLocal());
   int targetH = (int)StringToInteger(StringSubstr(Wochenbericht_Uhrzeit, 0, 2));
   int targetM = (int)StringToInteger(StringSubstr(Wochenbericht_Uhrzeit, 3, 2));

   bool wochenberichtErlaubt = false;
   if(Wochenbericht_Tag == Nur_Freitag && cd == 5)        wochenberichtErlaubt = true;
   else if(Wochenbericht_Tag == Nur_Sonntag && cd == 0)   wochenberichtErlaubt = true;
   else if(Wochenbericht_Tag == Fr_Und_So && (cd == 5 || cd == 0)) wochenberichtErlaubt = true;

   if(wochenberichtErlaubt && bh == targetH && bm == targetM && !wochenberichtGesendet)
   {
      wochenberichtGesendet = true;
      double basis = BerechneInvestmentBasis();
      double p = 0;
      int w = 0, l = 0;
      for(int k = OrdersHistoryTotal() - 1; k >= 0; k--)
      {
         if(OrderSelect(k, SELECT_BY_POS, MODE_HISTORY)
            && OrderCloseTime() >= wocheStartZeit
            && OrderSymbol() == Symbol())
         {
            double pr = OrderProfit() + OrderSwap() + OrderCommission();
            p += pr;
            if(pr > 0) w++;
            else if(pr < 0) l++;
         }
      }

      string nl = CharToString(10);
      string msg = "WOCHENBERICHT" + nl + Konto_Bezeichnung + nl + MSG_SEP;
      msg += "Profit: "         + FormatGeld(p) + " " + g_Waehrungssymbol + nl;
      msg += "Wochen Rendite: " + FormatRendite(p, basis) + " vom Investment" + nl;
      msg += "Trades: " + IntegerToString(w) + " Win / " + IntegerToString(l) + " Loss" + nl;
      msg += "Naechste Woche:" + nl + GetHandelstageNaechsteWoche();

      SendeFotoURL(WeeklyReport_URL, "", Chat_ID);
      SendeText(msg, Chat_ID);
      Print("Wochenbericht gesendet.");
   }

   // Reset-Flag: Samstag setzt das Flag wieder zurueck fuer naechste Woche
   if(cd == 6) wochenberichtGesendet = false;
}

//+------------------------------------------------------------------+
//| OnInit                                                            |
//+------------------------------------------------------------------+
int OnInit()
{
   // V7.0: Konto-Setup
   g_Waehrungssymbol = (Waehrungssymbol == WAHR_EUR) ? "EUR" : "$";
   g_FileSuffix      = "_" + IntegerToString(Magic);

   // Wochenstart berechnen (Montag 00:00 dieser Woche)
   {
      datetime jetzt = TimeLocal();
      int dow = TimeDayOfWeek(jetzt);
      if(dow == 0) dow = 7;
      int tageZurueck = (dow == 1) ? 0 : (dow - 1);
      MqlDateTime dtMo;
      TimeToStruct(jetzt - tageZurueck * 86400, dtMo);
      dtMo.hour = 0; dtMo.min = 0; dtMo.sec = 0;
      wocheStartZeit     = StructToTime(dtMo);
      equityStartWoche   = AccountEquity();
      wocheResetErledigt = true;
   }

   equityStartTag = AccountEquity();
   maxEquityHeute = equityStartTag;
   minEquityHeute = equityStartTag;
   EA_StartZeit   = TimeCurrent();

   // V7.0: Tickets laden + alte als "schon gemeldet" vormerken
   LadeGesendeteTickets();
   VormerkenAlleHistorischenTrades();

   g_prompt = PromptLaden(Prompt_Datei);
   if(StringLen(g_prompt) == 0)
   {
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

   if(Maske_Aktiv == Ja) MaskePlatzieren();

   Print("Chart Breite: ", ChartGetInteger(0, CHART_WIDTH_IN_PIXELS), " Pixel");
   Print("Chart Hoehe: ",  ChartGetInteger(0, CHART_HEIGHT_IN_PIXELS), " Pixel");

   if(Crop_Aktiv == Ja)
      Print("CROP AKTIV: Screenshot ", Crop_Breite_Pixel, "x", Crop_Hoehe_Pixel, " (rechtsbuendig)");
   else
      Print("CROP AUS: kompletter Chart wird gesendet");

   int buys  = ZaehleOffeneTrades(OP_BUY);
   int sells = ZaehleOffeneTrades(OP_SELL);

   EventSetTimer(1);
   Print("=== GOLDY AI TRADER V7.0 gestartet ===");
   Print("Konto: ", Konto_Bezeichnung, " | Typ: ",
         (Konto_Typ == Pro_Cent ? "Pro_Cent" :
          Konto_Typ == Pro      ? "Pro" :
          Konto_Typ == ECN      ? "ECN" : "Prime"),
         " | Waehrung: ", g_Waehrungssymbol);
   Print("KI-Modell: ", GPTModelToString(KI_Modell), " | Bild-Detail: ", Bild_Detail);
   Print("Intervall: ", Analyse_Intervall, " Sek");
   Print("Pyramiding: max ", Max_Trades_Pro_Richtung, " Trades pro Richtung, Cooldown ", Min_Sekunden_Zw_Trades, "s");
   if(Modus_Umdrehen == Ja) Print("UMDREHEN-MODUS AKTIV");
   else                     Print("Modus GETRENNT");
   if(Screenshot_Aktiv == Ja)
   {
      Print("BRIDGE AKTIV - Request: ", Bridge_Request_Datei, " | Done: ", Bridge_Done_Datei);
      Print("Screenshot bei Open=", (Screenshot_Bei_Open==Ja?"Ja":"Nein"),
            " | bei Close=", (Screenshot_Bei_Close==Ja?"Ja":"Nein"),
            " | Timeout=", Bridge_Max_Warten_Sek, "s");
   }
   else Print("BRIDGE AUS - kein Live-Screenshot");
   Print("Tagesbericht: ",  (Tagesbericht_Aktiv  ? Tagesbericht_Uhrzeit  : "AUS"));
   Print("Wochenbericht: ", (Wochenbericht_Aktiv ? Wochenbericht_Uhrzeit : "AUS"));
   Print("Aktuell offen: BUY=", buys, "/", Max_Trades_Pro_Richtung, " SELL=", sells, "/", Max_Trades_Pro_Richtung);

   // V7.0: Startup-Bild + Text an Telegram
   if(StringLen(Bot_Token) >= 10 && StringLen(Chat_ID) >= 5)
   {
      SendeFotoURL(Startup_URL, "", Chat_ID);
      string nl = CharToString(10);
      string startMsg = "GOLDY AI TRADER V7.0 aktiv" + nl + Konto_Bezeichnung
                      + nl + "Symbol: " + Symbol()
                      + nl + "KI-Modell: " + GPTModelToString(KI_Modell);
      SendeText(startMsg, Chat_ID);
   }

   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
   EventKillTimer();
   ObjectDelete("GOLDY_MASKE");
   SpeichereGesendeteTickets();
   Print("=== GOLDY AI TRADER V7.0 beendet ===");
}

//+------------------------------------------------------------------+
//| HAUPTLOGIK                                                       |
//+------------------------------------------------------------------+
void OnTimer()
{
   // V7.0: Equity-Tracking heute (max/min)
   double eq = AccountEquity();
   if(eq > maxEquityHeute) maxEquityHeute = eq;
   if(minEquityHeute == 0 || eq < minEquityHeute) minEquityHeute = eq;

   // V7.0: Berichts-Trigger jede Sekunde pruefen
   PruefeTagesbericht();
   PruefeWochenbericht();

   // KI-Analyse-Throttling
   uint jetzt = GetTickCount();
   if(g_letzte_analyse > 0 && (jetzt - g_letzte_analyse) < (uint)Analyse_Intervall * 1000)
      return;
   g_letzte_analyse = jetzt;

   string signal = KI_Analyse();

   int buys  = ZaehleOffeneTrades(OP_BUY);
   int sells = ZaehleOffeneTrades(OP_SELL);

   Print("KI-Signal: ", signal,
         " | Offen: BUY=", buys, "/", Max_Trades_Pro_Richtung,
         " SELL=", sells, "/", Max_Trades_Pro_Richtung);

   if(signal == "BUY")
   {
      if(Modus_Umdrehen == Ja && buys >= 1)
      {
         Print("BUY ignoriert - schon ", buys, " BUY offen (UMDREHEN: nur 1 pro Richtung)");
         return;
      }
      if(Modus_Umdrehen == Ja && sells > 0)
      {
         Print(">>> UMDREHEN: Schliesse alle ", sells, " SELL-Trades");
         SchliesseAlleTrades(OP_SELL);
         g_letzter_sell_zeit = 0;
         sells = 0;
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
   else if(signal == "SELL")
   {
      if(Modus_Umdrehen == Ja && sells >= 1)
      {
         Print("SELL ignoriert - schon ", sells, " SELL offen (UMDREHEN: nur 1 pro Richtung)");
         return;
      }
      if(Modus_Umdrehen == Ja && buys > 0)
      {
         Print(">>> UMDREHEN: Schliesse alle ", buys, " BUY-Trades");
         SchliesseAlleTrades(OP_BUY);
         g_letzter_buy_zeit = 0;
         buys = 0;
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
   else if(signal == "CLOSE_BUY")
   {
      if(buys > 0)
      {
         Print(">>> SCHLIESSE ALLE BUY-Trades (", buys, " Stueck)");
         SchliesseAlleTrades(OP_BUY);
         g_letzter_buy_zeit = 0;
      }
      else Print("CLOSE_BUY ignoriert - keine BUY-Trades offen");
   }
   else if(signal == "CLOSE_SELL")
   {
      if(sells > 0)
      {
         Print(">>> SCHLIESSE ALLE SELL-Trades (", sells, " Stueck)");
         SchliesseAlleTrades(OP_SELL);
         g_letzter_sell_zeit = 0;
      }
      else Print("CLOSE_SELL ignoriert - keine SELL-Trades offen");
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
//| TRADE FUNKTIONEN                                                 |
//+------------------------------------------------------------------+
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
   int ticket = OrderSend(Symbol(), typ, Lot, preis, 10, 0, 0, "GOLDY_V7", Magic, 0, clrNONE);

   if(ticket > 0)
   {
      string richtung = (typ == OP_BUY) ? "BUY" : "SELL";
      Print("TRADE GEOEFFNET: ", richtung, " @ ", DoubleToStr(preis, Digits), " Ticket: ", ticket);
      SendeNeuerTrade(typ, preis, ticket);
   }
   else
      Print("TRADE FEHLER: ", GetLastError());
}

void SchliesseAlleTrades(int typ)
{
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
         SendeTradeGeschlossen(typ, open_preis, preis, profit, open_zeit, ist_win, ticket);
      }
      else
         Print("CLOSE FEHLER fuer Ticket ", ticket, ": ", GetLastError());
   }
}

//+------------------------------------------------------------------+
//| V7.0: SCREENSHOT-BRIDGE                                          |
//+------------------------------------------------------------------+
bool WarteAufScreenshot(string anlass)
{
   if(FileIsExist(Bridge_Done_Datei, FILE_COMMON))
      FileDelete(Bridge_Done_Datei, FILE_COMMON);

   int fh = FileOpen(Bridge_Request_Datei, FILE_WRITE | FILE_TXT | FILE_COMMON);
   if(fh == INVALID_HANDLE)
   {
      Print("Bridge: KANN Request-Datei nicht schreiben! Error=", GetLastError(),
            " | Pfad=", Bridge_Request_Datei);
      return false;
   }
   FileWrite(fh, "anlass=", anlass);
   FileWrite(fh, "symbol=", Symbol());
   FileWrite(fh, "timestamp=", (int)TimeCurrent());
   FileClose(fh);
   Print("Bridge: Request gesendet (", anlass, ") - warte auf Done...");

   uint start = GetTickCount();
   uint timeout_ms = (uint)Bridge_Max_Warten_Sek * 1000;
   int  poll_ms   = (Bridge_Poll_ms < 50 ? 50 : Bridge_Poll_ms);

   while(GetTickCount() - start < timeout_ms)
   {
      Sleep(poll_ms);
      if(FileIsExist(Bridge_Done_Datei, FILE_COMMON))
      {
         uint dauer = GetTickCount() - start;
         FileDelete(Bridge_Done_Datei, FILE_COMMON);
         if(FileIsExist(Bridge_Request_Datei, FILE_COMMON))
            FileDelete(Bridge_Request_Datei, FILE_COMMON);
         Print("Bridge: Screenshot bestaetigt nach ", dauer, " ms");
         return true;
      }
   }

   Print("Bridge: TIMEOUT nach ", Bridge_Max_Warten_Sek, "s - keine Bestaetigung. Fahre fort.");
   if(FileIsExist(Bridge_Request_Datei, FILE_COMMON))
      FileDelete(Bridge_Request_Datei, FILE_COMMON);
   return false;
}

//+------------------------------------------------------------------+
//| TELEGRAM NACHRICHTEN                                             |
//+------------------------------------------------------------------+
void SendeNeuerTrade(int typ, double preis, int ticket)
{
   // V7.0: Persistenz-Check (kein Doppel-Send nach Neustart)
   string ticket_str = IntegerToString(ticket);
   if(IstInListe(TPR_sentOpen, ticket_str))
   {
      Print("Trade ", ticket, " bereits gemeldet (Persistenz) - skip");
      return;
   }

   string nl = CharToString(10);
   string richtung = (typ == OP_BUY) ? "BUY" : "SELL";

   // V7.0: ZUERST Live-Screenshot vom externen EA anfordern
   if(Screenshot_Aktiv == Ja && Screenshot_Bei_Open == Ja)
      WarteAufScreenshot("OPEN_" + richtung);

   // 1. Deko-Bild (NewTrade)
   if(NT_Bild_Senden == Ja)
      SendeFotoURL(NewTrade_URL, "", Chat_ID);

   // 2. Text-Nachricht
   string msg = "NEUER TRADE" + nl;
   if(NT_Richtung == Ja) msg += richtung + nl;
   if(NT_Waehrung == Ja) msg += Symbol() + nl;
   if(NT_Preis == Ja)    msg += "Entry: " + DoubleToStr(preis, Digits) + nl;
   if(NT_Datum == Ja)    msg += "Datum: "   + TimeToStr(TimeLocal(), TIME_DATE) + nl;
   if(NT_Uhrzeit == Ja)  msg += "Uhrzeit: " + TimeToStr(TimeLocal(), TIME_SECONDS) + nl;
   if(NT_Lot == Ja)      msg += "Lot: "     + DoubleToStr(Lot, 2) + nl;

   SendeText(msg, Chat_ID);

   // V7.0: Persistenz speichern
   TPR_sentOpen = FuegeZuListe(TPR_sentOpen, ticket_str);
   SpeichereGesendeteTickets();
}

void SendeTradeGeschlossen(int typ, double open_preis, double close_preis, double profit,
                           datetime open_zeit, bool ist_win, int ticket)
{
   // V7.0: Persistenz-Check
   string ticket_str = IntegerToString(ticket);
   if(IstInListe(TPR_sentClosed, ticket_str))
   {
      Print("Close-Trade ", ticket, " bereits gemeldet (Persistenz) - skip");
      return;
   }

   string nl = CharToString(10);
   string richtung = (typ == OP_BUY) ? "BUY" : "SELL";
   int dauer_min = (int)((TimeCurrent() - open_zeit) / 60);

   // V7.0: ZUERST Live-Screenshot vom externen EA anfordern
   if(Screenshot_Aktiv == Ja && Screenshot_Bei_Close == Ja)
      WarteAufScreenshot("CLOSE_" + richtung);

   // 1. Deko-Bild (CloseTrade)
   if(CT_Bild_Senden == Ja)
      SendeFotoURL(CloseTrade_URL, "", Chat_ID);

   // V7.0: NEUE REIHENFOLGE
   // 1.GESCHLOSSEN 2.Symbol 3.Lot 4.Datum 5.Uhrzeit 6.Entry 7.Close 8.Dauer 9.Ergebnis 10.P/L
   string msg = "TRADE GESCHLOSSEN" + nl;                              // 1
   if(CT_Waehrung == Ja) msg += Symbol() + nl;                         // 2
   if(CT_Lot == Ja)      msg += "Lot: "     + DoubleToStr(Lot, 2) + nl;// 3
   if(CT_Datum == Ja)    msg += "Datum: "   + TimeToStr(TimeLocal(), TIME_DATE) + nl;     // 4
   if(CT_Uhrzeit == Ja)  msg += "Uhrzeit: " + TimeToStr(TimeLocal(), TIME_SECONDS) + nl;  // 5
   if(CT_Entry == Ja)    msg += "Entry: "   + DoubleToStr(open_preis, Digits) + nl;       // 6
   if(CT_Close == Ja)    msg += "Close: "   + DoubleToStr(close_preis, Digits) + nl;      // 7
   if(CT_Dauer == Ja)    msg += "Dauer: "   + IntegerToString(dauer_min) + " min" + nl;   // 8
   msg += "Ergebnis: " + (ist_win ? "WIN" : "LOSS") + nl;              // 9
   if(CT_PL == Ja)       msg += "P/L: " + FormatGeld(profit) + " " + g_Waehrungssymbol;   // 10

   SendeText(msg, Chat_ID);

   // 3. Win/Loss Bild
   if(ist_win  && Win_Bild  == Ja) SendeFotoURL(Winning_URL, "", Chat_ID);
   if(!ist_win && Loss_Bild == Ja) SendeFotoURL(Loss_URL, "", Chat_ID);

   // V7.0: Persistenz speichern
   TPR_sentClosed = FuegeZuListe(TPR_sentClosed, ticket_str);
   SpeichereGesendeteTickets();
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
   string datei = (Debug_Bild_Speichern == Ja) ? "goldy_v7_letztes_bild.png" : "goldy_v7_temp.png";

   bool ok;
   if(Crop_Aktiv == Ja)
   {
      ok = ChartScreenShot(0, datei, Crop_Breite_Pixel, Crop_Hoehe_Pixel, ALIGN_RIGHT);
      if(ok) Print("Screenshot CROP: ", Crop_Breite_Pixel, "x", Crop_Hoehe_Pixel, " (rechtsbuendig)");
   }
   else
   {
      ok = ChartScreenShot(0, datei, 1280, 800, ALIGN_RIGHT);
      if(ok) Print("Screenshot FULL: 1280x800");
   }

   if(!ok) { Print("Screenshot FEHLER: ", GetLastError()); return "NONE"; }

   uchar bild[];
   int fh = FileOpen(datei, FILE_READ | FILE_BIN);
   if(fh == INVALID_HANDLE) return "NONE";
   int size = (int)FileSize(fh);
   ArrayResize(bild, size);
   FileReadArray(fh, bild, 0, size);
   FileClose(fh);

   if(Debug_Bild_Speichern == Nein)
      FileDelete(datei);

   string b64 = Base64(bild);
   string content = OpenAI_Senden(b64);
   if(StringLen(content) == 0) return "NONE";

   string signal = JsonWert(content, "signal");
   string conf   = JsonWert(content, "confidence");
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

   string model_str = GPTModelToString(KI_Modell);

   string body = "{" + dq + "model" + dq + ":" + dq + model_str + dq + ",";
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
