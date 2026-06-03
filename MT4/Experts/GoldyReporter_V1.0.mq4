//+------------------------------------------------------------------+
//|                          GoldyReporter V1.0                      |
//|                             Copyright 2026, Neubytrader          |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Neubytrader"
#property link      "https://t.me/Neubytrader"
#property version   "1.0"
#property strict
#property description "Goldy Reporter V1.0"
#property description "Telegram-Bot | Remote-Control | Scheduler | Tages-/Wochenberichte"
#property description "Drawdown-Monitor | Tagesziele | Live-Dashboard | Mute-Funktion"
#property description "Support: https://t.me/Neubytrader"
#import "user32.dll"
int PostMessageW(int hWnd, int Msg, int wParam, int lParam);
int GetAncestor(int hWnd, int gaFlags);
#import
#define WM_COMMAND        0x0111
#define GA_ROOT           2
#define AUTOTRADING_CMD   33020
#define OP_BALANCE        6
#define MSG_SEP           "...\n"
enum ENUM_JA_NEIN { Nein = 0, Ja = 1 };
enum ENUM_NOTIF_STIL { Bild_und_Nachricht = 0, Nur_Bild = 1, Nur_Nachricht = 2, KEINE = 3 };
enum ENUM_KONTO_TYP { Pro_Cent = 0, Pro = 1, ECN = 2, Prime = 3 };
enum ENUM_WAEHRUNG { WAHR_USD = 0, WAHR_EUR = 1 };
enum ENUM_TAGES_BERICHT_TAGE { Mo_Fr = 0, Mo_So = 1 };
enum ENUM_WOCHEN_BERICHT_TAGE { Nur_Freitag = 0, Nur_Sonntag = 1, Fr_Und_So = 2 };
enum ENUM_SCHED_ZEITBASIS { Lokale_Zeit, Server_Zeit };
//====================== INPUTS (Deutsch & Sortiert) ================
input string   Telegram_Bot_Token          = "Telegram Bot Token";
input string   Telegram_Chat_ID            = "Telegram Chat ID";
input string   Telegram_Erlaubte_UserID    = "Erlaubte Telegram User-ID";
input string   RoboForex_KontoNr           = "RoboForex Konto-Nr. (zur Isolierung)";
input string   Konto_Bezeichnung           = "MT4 #1 - Xau Master 6.0";
input ENUM_KONTO_TYP Konto_Typ             = Pro_Cent;
input ENUM_WAEHRUNG Währungssymbol         = WAHR_USD;
input bool     Tagesziel_Benachrichtigung  = true;
input double   Tagesziel_Betrag            = 1500.0;
input string   __Benachrichtigungen_Stumm  = "=== BENACHRICHTIGUNGEN STUMM ===";
input ENUM_JA_NEIN Stummzeit_Aktivieren    = Nein;
input string   Stummzeit_Fenster           = "13:00-18:00";
input string   __Benachrichtigungen_Stil   = "=== BENACHRICHTIGUNGEN ANZEIGESTIL ===";
input ENUM_NOTIF_STIL Stil_Neuer_Trade     = Bild_und_Nachricht;
input ENUM_NOTIF_STIL Stil_Gewinn_Trade    = Bild_und_Nachricht;
input ENUM_NOTIF_STIL Stil_Verlust_Trade   = Bild_und_Nachricht;
input string   __Handelszeiten_Scheduler   = "=== HANDELSZEITEN (SCHEDULER) ===";
input bool     Scheduler_Aktiv             = true;
input ENUM_SCHED_ZEITBASIS Scheduler_Zeitbasis = Server_Zeit;
input string   Zeit_Montag                 = "12:00-21:00";
input string   Zeit_Dienstag               = "06:00-21:00";
input string   Zeit_Mittwoch               = "06:00-21:00";
input string   Zeit_Donnerstag             = "06:00-21:00";
input string   Zeit_Freitag                = "06:00-15:00";
input string   Zeit_Samstag                = "";
input string   Zeit_Sonntag                = "";
input string   __Sicherheitseinstellungen  = "=== SICHERHEITS-EINSTELLUNGEN ===";
input bool     Positionen_Schliessen_Bei_Ende = false;
input bool     Warten_Bis_Keine_Positionen = true;
input bool     Warten_Bis_Keine_Orders     = true;
input bool     Tagesbericht_Aktiv          = true;
input string   Tagesbericht_Uhrzeit        = "21:58";
input bool     Wochenbericht_Aktiv         = true;
input string   Wochenbericht_Uhrzeit       = "21:59";
input ENUM_TAGES_BERICHT_TAGE Tagesbericht_Wochentage = Mo_Fr;
input ENUM_WOCHEN_BERICHT_TAGE Wochenbericht_Tag = Nur_Freitag;
input double   Drawdown_Limit_Prozent      = 30.0;
input bool     Benachrichtigung_Neue_Trades = true;
input bool     Benachrichtigung_Geschlossene_Trades = true;
// === REMOTE CONTROL ===
input bool     Fernsteuerung_Aktiv         = true;
input int      Fernsteuerung_Abfrage_Sekunden = 5;
//====================== GLOBALE VARIABLEN ===========================
#define CLR_BG          0x121212
#define CLR_PANEL       0x000000
#define CLR_GOLD        0x20A5DA
#define CLR_GREEN       0x00CC66
#define CLR_TEXT        0xE8E8E8
#define CLR_TEXT_DIM    0x888888
#define CLR_ORANGE      0xFF9900
#define CLR_RED         0x0000CC
#define CLR_TOGGLE_ON   0x20A5DA
#define CLR_TOGGLE_OFF  0x2A2A2A
#define CLR_EDIT_BG     0x0F0F0F
#define CLR_INPUT_BG    0x1E1E1E
#define CLR_BORDER      0x333333
#define CLR_TRANSPARENT 0x000000
int    PW = 630, PH = 760;
int    COL_L = 25, INPUT_X = 320, TOGGLE_X = 430, ROW_H = 30;
string PFX = "TPR_";
int    ui_BoxY = 0;
string ui_AccountName, ui_DailyTimeStr, ui_WeeklyTimeStr;
double ui_DrawdownLimit;
bool   ui_DailyReport=true, ui_WeeklyReport=true, ui_DrawdownWarn=true;
bool   ui_NewTradeNotif=true, ui_ClosedTradeNotif=true;
string TPR_sentOpen   = "";
string TPR_sentClosed = "";
bool   berichtGesendetHeute=false, wochenberichtGesendet=false;
double equityStartTag=0, equityStartWoche=0, maxEquityHeute=0, minEquityHeute=0;
datetime letzterBerichtTag=0, wocheStartZeit=0;
bool   wocheResetErledigt=false, drawdownWarnungGesendet=false;
int    timeOffset=0;
datetime EA_StartZeit = 0;
int      schedStatus = 0;
bool     schedWarErlaubt = false;
bool     sessionOffGesendet = false;
bool     manuellesSperreAktiv = false;
bool     ziel25Erreicht=false, ziel50Erreicht=false, ziel75Erreicht=false, ziel100Erreicht=false;
double   zielHoechsterWertWaehrendMute = 0;
bool     zielMuteNachrichtGesendet = false;
string g_Währungssymbol = "$";
string g_FileSuffix = "";
string Startup_Bild_URL      = "https://i.postimg.cc/W4FB6Zbd/startup.jpg";
string NewTrade_Bild_URL     = "https://i.postimg.cc/tJ5wCt20/new-trade.jpg";
string Winning_Bild_URL      = "https://i.postimg.cc/pLy4Rjjg/winning.jpg";
string Loss_Bild_URL         = "https://i.postimg.cc/J0PYW7zr/loss.jpg";
string Drawdown_Bild_URL     = "https://i.postimg.cc/y8JQwHqP/drawdown.jpg";
string DayReport_Bild_URL    = "https://i.postimg.cc/tJCDD0tx/day-report.jpg";
string WeeklyReport_Bild_URL = "https://i.postimg.cc/c4CXnSJC/weekly-report.jpg";
string SessionOn_Bild_URL    = "https://i.postimg.cc/50wB5V7Q/session-on.jpg";
string SessionOff_Bild_URL   = "https://i.postimg.cc/Bbp2yCGZ/session-off.jpg";
string Ziel25_Bild_URL       = "https://i.postimg.cc/CLrZzFxc/25-Targed.jpg";
string Ziel50_Bild_URL       = "https://i.postimg.cc/NfFFhWxv/50-Targed.jpg";
string Ziel75_Bild_URL       = "https://i.postimg.cc/V6zsKTN2/75-Targed.jpg";
string Ziel100_Bild_URL      = "https://i.postimg.cc/Y0spqCz5/100-Targed.jpg";
// === REMOTE CONTROL STATE ===
int      cmd_lastUpdateID = 0;
datetime cmd_lastPoll = 0;
//====================== HILFSFUNKTIONEN =============================
string FormatGeld(double wert) {
double val = (Konto_Typ == Pro_Cent) ? wert / 100.0 : wert;
string sign = (val >= 0) ? "+" : "";
return sign + DoubleToString(val, 2);
}
double BerechneInvestmentBasis() {
double basis = 0;
int tot = OrdersHistoryTotal();
for(int k = 0; k < tot; k++) {
if(OrderSelect(k, SELECT_BY_POS, MODE_HISTORY))
if(OrderType() == OP_BALANCE) basis += OrderProfit();
}
double result = (basis > 0 ? basis : AccountBalance());
if(Konto_Typ == Pro_Cent) result = result / 100.0;
return result;
}
string FormatRendite(double profit, double basis) {
if(basis <= 0) return "";
double profitInUsd = (Konto_Typ == Pro_Cent) ? profit / 100.0 : profit;
double pct = (profitInUsd / basis) * 100.0;
return (pct >= 0 ? "+" : "") + DoubleToString(pct, 3) + "%";
}
bool IstInListe(string liste, string ticket) {
if(StringLen(liste) == 0) return false;
return(StringFind("," + liste, "," + ticket + ",") >= 0);
}
string FuegeZuListe(string liste, string ticket) {
if(!IstInListe(liste, ticket)) liste += ticket + ",";
return liste;
}
string EntferneAusListe(string liste, string ticket) {
string search = "," + ticket + ",";
int pos = StringFind("," + liste, search);
if(pos >= 0) {
string prefix = StringSubstr(liste, 0, pos-1);
string suffix = StringSubstr(liste, pos + StringLen(search) - 1);
return prefix + suffix;
}
return liste;
}
void LadeGesendeteTickets() {
TPR_sentOpen = "";
int h1 = FileOpen(StringFormat("goldy%s_open.dat", g_FileSuffix), FILE_BIN|FILE_READ);
if(h1 != INVALID_HANDLE) { TPR_sentOpen = FileReadString(h1, -1); FileClose(h1); }
if(StringLen(TPR_sentOpen) > 0 && StringSubstr(TPR_sentOpen, StringLen(TPR_sentOpen)-1, 1) != ",") TPR_sentOpen += ",";
TPR_sentClosed = "";
int h2 = FileOpen(StringFormat("goldy%s_closed.dat", g_FileSuffix), FILE_BIN|FILE_READ);
if(h2 != INVALID_HANDLE) { TPR_sentClosed = FileReadString(h2, -1); FileClose(h2); }
if(StringLen(TPR_sentClosed) > 0 && StringSubstr(TPR_sentClosed, StringLen(TPR_sentClosed)-1, 1) != ",") TPR_sentClosed += ",";
}
void SpeichereGesendeteTickets() {
int h1 = FileOpen(StringFormat("goldy%s_open.dat", g_FileSuffix), FILE_BIN|FILE_WRITE);
if(h1 != INVALID_HANDLE) { FileWriteString(h1, TPR_sentOpen, StringLen(TPR_sentOpen)); FileClose(h1); }
int h2 = FileOpen(StringFormat("goldy%s_closed.dat", g_FileSuffix), FILE_BIN|FILE_WRITE);
if(h2 != INVALID_HANDLE) { FileWriteString(h2, TPR_sentClosed, StringLen(TPR_sentClosed)); FileClose(h2); }
}
void VormerkenAlleHistorischenTrades() {
int vorgemerkt = 0;
int tot = OrdersHistoryTotal();
for(int k = 0; k < tot; k++) {
if(OrderSelect(k, SELECT_BY_POS, MODE_HISTORY)) {
int ot = OrderType(); if(ot != OP_BUY && ot != OP_SELL) continue;
string t = IntegerToString(OrderTicket());
if(!IstInListe(TPR_sentClosed, t)) { TPR_sentClosed += t + ","; vorgemerkt++; }
}
}
int totOpen = OrdersTotal();
for(int k = 0; k < totOpen; k++) {
if(OrderSelect(k, SELECT_BY_POS, MODE_TRADES)) {
int ot = OrderType(); if(ot != OP_BUY && ot != OP_SELL) continue;
string t = IntegerToString(OrderTicket());
if(!IstInListe(TPR_sentOpen, t)) { TPR_sentOpen += t + ","; vorgemerkt++; }
}
}
if(vorgemerkt > 0) { SpeichereGesendeteTickets(); Print("Tickets vorgemerkt: ", vorgemerkt); }
}
string UrlEncode(string txt) {
string result = ""; int len = StringLen(txt);
for(int i = 0; i < len; i++) {
ushort c = StringGetCharacter(txt, i);
if((c >= 'A' && c <= 'Z') || (c >= 'a' && c <= 'z') || (c >= '0' && c <= '9') || c == '-' || c == '_' || c == '.' || c == '~') result += StringSubstr(txt, i, 1);
else if(c == 32) result += "%20";
else if(c == 13) continue;
else if(c == 10) result += "%0A";
else if(c == 33) result += "%21"; else if(c == 43) result += "%2B"; else if(c == 47) result += "%2F";
else if(c == 58) result += "%3A"; else if(c == 63) result += "%3F"; else if(c == 64) result += "%40";
else if(c == 35) result += "%23"; else if(c == 37) result += "%25"; else if(c == 38) result += "%26";
else if(c == 61) result += "%3D";
else { uchar arr[]; string ch = StringSubstr(txt, i, 1); StringToCharArray(ch, arr, 0, -1, CP_UTF8); for(int j = 0; j < ArraySize(arr)-1; j++) { string hex = "0123456789ABCDEF"; result += "%" + StringSubstr(hex, arr[j]/16, 1) + StringSubstr(hex, arr[j]%16, 1); } }
}
return result;
}
bool CheckZeitInFenster(datetime checkTime, string schedule) {
string windows[]; int count = StringSplit(schedule, ',', windows);
for(int i = 0; i < count; i++) {
string win = StringTrimLeft(StringTrimRight(windows[i])); if(StringLen(win) == 0) continue;
string parts[]; if(StringSplit(win, '-', parts) != 2) continue;
string startStr = StringTrimLeft(StringTrimRight(parts[0])); string endStr = StringTrimLeft(StringTrimRight(parts[1]));
if(StringLen(startStr) < 4 || StringLen(endStr) < 4) continue;
int startH = (int)StringToInteger(StringSubstr(startStr, 0, 2)); int startM = (int)StringToInteger(StringSubstr(startStr, StringFind(startStr, ":") + 1, 2));
int endH = (int)StringToInteger(StringSubstr(endStr, 0, 2)); int endM = (int)StringToInteger(StringSubstr(endStr, StringFind(endStr, ":") + 1, 2));
MqlDateTime dt; TimeToStruct(checkTime, dt);
dt.hour = startH; dt.min = startM; dt.sec = 0; datetime startTime = StructToTime(dt);
dt.hour = endH; dt.min = endM; dt.sec = 0; datetime endTime = StructToTime(dt);
if(startTime < endTime) { if(checkTime >= startTime && checkTime < endTime) return true; }
else { if(checkTime >= startTime || checkTime < endTime) return true; }
}
return false;
}
bool IsAutoTradingErlaubt() {
if(!Scheduler_Aktiv) return true;
datetime now = (Scheduler_Zeitbasis == Server_Zeit) ? TimeCurrent() : TimeLocal();
int dow = TimeDayOfWeek(now); if(dow == 0) dow = 7;
string schedule = "";
switch(dow) { case 1: schedule = Zeit_Montag; break; case 2: schedule = Zeit_Dienstag; break; case 3: schedule = Zeit_Mittwoch; break; case 4: schedule = Zeit_Donnerstag; break; case 5: schedule = Zeit_Freitag; break; case 6: schedule = Zeit_Samstag; break; case 7: schedule = Zeit_Sonntag; break; }
schedule = StringTrimLeft(StringTrimRight(schedule));
if(StringLen(schedule) == 0) return false;
return CheckZeitInFenster(now, schedule);
}
string GetTagName(int dow) { string days[8] = {"", "Mo", "Di", "Mi", "Do", "Fr", "Sa", "So"}; if(dow >= 1 && dow <= 7) return days[dow]; return ""; }
string GetScheduleForDay(int dow) { switch(dow) { case 1: return Zeit_Montag; case 2: return Zeit_Dienstag; case 3: return Zeit_Mittwoch; case 4: return Zeit_Donnerstag; case 5: return Zeit_Freitag; case 6: return Zeit_Samstag; case 7: return Zeit_Sonntag; } return ""; }
string GetAktuelleSessionInfo() {
datetime now = (Scheduler_Zeitbasis == Server_Zeit) ? TimeCurrent() : TimeLocal();
int dow = TimeDayOfWeek(now); if(dow == 0) dow = 7;
string schedule = StringTrimLeft(StringTrimRight(GetScheduleForDay(dow)));
if(StringLen(schedule) == 0) return "";
string windows[]; StringSplit(schedule, ',', windows); string win = StringTrimLeft(StringTrimRight(windows[0]));
MqlDateTime dt; TimeToStruct(now, dt); string datum = StringFormat("%02d.%02d.%04d", dt.day, dt.mon, dt.year);
return GetTagName(dow) + ", " + datum + "\nSession: " + win;
}
string GetNaechsteSessionInfo() {
datetime now = (Scheduler_Zeitbasis == Server_Zeit) ? TimeCurrent() : TimeLocal();
for(int dayOffset = 1; dayOffset <= 8; dayOffset++) {
datetime futureDay = now + dayOffset * 86400; int dow = TimeDayOfWeek(futureDay); if(dow == 0) dow = 7;
string schedule = StringTrimLeft(StringTrimRight(GetScheduleForDay(dow)));
if(StringLen(schedule) == 0) continue;
string windows[]; StringSplit(schedule, ',', windows); string win = StringTrimLeft(StringTrimRight(windows[0]));
if(StringLen(win) == 0) continue;
MqlDateTime dt; TimeToStruct(futureDay, dt); string datum = StringFormat("%02d.%02d.%04d", dt.day, dt.mon, dt.year);
return GetTagName(dow) + ", " + datum + "\nSession: " + win;
}
return "Unbekannt";
}
bool HatOffenePositionen() { for(int i = 0; i < OrdersTotal(); i++) if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) if(OrderType() == OP_BUY || OrderType() == OP_SELL) return true; return false; }
bool HatPendingOrders() { for(int i = 0; i < OrdersTotal(); i++) if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) if(OrderType() == OP_BUYLIMIT || OrderType() == OP_SELLLIMIT || OrderType() == OP_BUYSTOP || OrderType() == OP_SELLSTOP) return true; return false; }
void SchliesseAllePositionen() {
for(int i = OrdersTotal() - 1; i >= 0; i--) {
if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) {
if(OrderType() == OP_BUY) OrderClose(OrderTicket(), OrderLots(), MarketInfo(OrderSymbol(), MODE_BID), 2, clrNONE);
else if(OrderType() == OP_SELL) OrderClose(OrderTicket(), OrderLots(), MarketInfo(OrderSymbol(), MODE_ASK), 2, clrNONE);
}
}
}
void ToggleAutoTradingButton(bool enable) {
if(!MQLInfoInteger(MQL_DLLS_ALLOWED)) return;
long chartWnd = ChartGetInteger(0, CHART_WINDOW_HANDLE);
if(chartWnd == 0) return;
int rootWnd = GetAncestor((int)chartWnd, GA_ROOT);
if(rootWnd == 0) return;
PostMessageW(rootWnd, WM_COMMAND, AUTOTRADING_CMD, 0);
}
void SetAutoTradingState(bool enable) {
if(!MQLInfoInteger(MQL_DLLS_ALLOWED)) return;
long chartWnd = ChartGetInteger(0, CHART_WINDOW_HANDLE);
int rootWnd = GetAncestor((int)chartWnd, GA_ROOT);
Print("Setze AutoTrading auf: ", enable ? "AN" : "AUS");
PostMessageW(rootWnd, WM_COMMAND, AUTOTRADING_CMD, 0);
Sleep(500);
bool status = TerminalInfoInteger(TERMINAL_TRADE_ALLOWED);
if(status != enable) {
Print("Korrektur nötig...");
Sleep(300);
PostMessageW(rootWnd, WM_COMMAND, AUTOTRADING_CMD, 0);
Sleep(500);
status = TerminalInfoInteger(TERMINAL_TRADE_ALLOWED);
}
Print("Finaler Status: ", status ? "AN" : "AUS");
}
int CountOpenPositions() {
int c=0;
for(int i=0; i<OrdersTotal(); i++) if(OrderSelect(i,SELECT_BY_POS,MODE_TRADES)) if(OrderType()==OP_BUY||OrderType()==OP_SELL) c++;
return c;
}
//====================== TELEGRAM SENDEN =============================
bool SendeTelegramFotoURL(string foto, string cap) {
if(StringLen(Telegram_Bot_Token) < 10 || StringLen(Telegram_Chat_ID) < 5) { Print("Telegram Fehler: Token/ID!"); return false; }
string url = "https://api.telegram.org/bot" + Telegram_Bot_Token + "/sendPhoto";
string data = "chat_id=" + Telegram_Chat_ID + "&photo=" + foto;
if(StringLen(cap) > 0) data += "&caption=" + UrlEncode(cap);
uchar req[], res[]; string res_headers = "";
int len = StringLen(data); if(len < 1) len = 1;
ArrayResize(req, len); StringToCharArray(data, req, 0, len, CP_UTF8);
int code = WebRequest("POST", url, "Content-Type: application/x-www-form-urlencoded", 10000, req, res, res_headers);
if(code == 200) { Print("Telegram Erfolg"); return true; } else {
ArrayResize(res, ArraySize(res)+1); res[ArraySize(res)-1]=0;
Print("Telegram FEHLER | HTTP: ", code, " | API: ", CharArrayToString(res, 0, -1, CP_UTF8));
return false;
}
}
bool SendeTelegramText(string txt) {
string url = "https://api.telegram.org/bot" + Telegram_Bot_Token + "/sendMessage";
string data = "chat_id=" + Telegram_Chat_ID + "&text=" + UrlEncode(txt);
uchar req[], res[]; string res_headers = "";
int len = StringLen(data); if(len < 1) len = 1;
ArrayResize(req, len); StringToCharArray(data, req, 0, len, CP_UTF8);
int code = WebRequest("POST", url, "Content-Type: application/x-www-form-urlencoded", 10000, req, res, res_headers);
return (code == 200);
}
//====================== COMMAND CHECKER =============================
void CheckRemoteCommands() {
if(!Fernsteuerung_Aktiv) return;
if(TimeCurrent() - cmd_lastPoll < Fernsteuerung_Abfrage_Sekunden) return;
cmd_lastPoll = TimeCurrent();
if(StringLen(Telegram_Bot_Token) < 10) return;
string url = "https://api.telegram.org/bot" + Telegram_Bot_Token + "/getUpdates?offset=" + IntegerToString(cmd_lastUpdateID + 1);
uchar req[], res[]; string res_headers = "";
int code = WebRequest("GET", url, "", 5000, req, res, res_headers);
if(code != 200) return;
ArrayResize(res, ArraySize(res) + 1); res[ArraySize(res) - 1] = 0;
string json = CharArrayToString(res, 0, -1, CP_UTF8);
int msgPos = StringFind(json, "\"message\":{");
if(msgPos < 0) return;
int idPos = StringFind(json, "\"update_id\":", 0);
if(idPos < 0) return;
idPos += 12;
int idEnd = StringFind(json, ",", idPos); if(idEnd < 0) idEnd = StringFind(json, "}", idPos);
int newID = (int)StringToInteger(StringSubstr(json, idPos, idEnd - idPos));
cmd_lastUpdateID = newID;
int userIdPos = StringFind(json, "\"from\":{", msgPos);
if(userIdPos < 0) return;
int uPos = StringFind(json, "\"id\":", userIdPos);
if(uPos < 0) return;
uPos += 5;
int uEnd = StringFind(json, ",", uPos);
string fromID = StringSubstr(json, uPos, uEnd - uPos);
int txtPos = StringFind(json, "\"text\":\"", msgPos);
if(txtPos < 0) return;
txtPos += 8;
int txtEnd = StringFind(json, "\"", txtPos);
string cmd = StringSubstr(json, txtPos, txtEnd - txtPos);
if(StringLen(cmd) > 0 && StringSubstr(cmd, 0, 1) == "/") cmd = StringSubstr(cmd, 1);
cmd = StringTrimLeft(StringTrimRight(cmd));
string lower = cmd;
for(int i = 0; i < StringLen(lower); i++) { int c = StringGetCharacter(lower, i); if(c >= 'A' && c <= 'Z') StringSetCharacter(lower, i, c + 32); }
Print("EMPFANGEN: Von ID=", fromID, " | Befehl=", lower);
if(StringFind(fromID, Telegram_Erlaubte_UserID) < 0) { Print("BLOCKIERT: ID nicht erlaubt"); return; }
if(lower == "off") {
Print("AKTION: Setze AutoTrading OFF (manuelle Sperre aktiv)");
manuellesSperreAktiv = true;
SetAutoTradingState(false);
SendeTelegramFotoURL(SessionOff_Bild_URL, "SESSION BEENDET\n" + ui_AccountName + "\n" + MSG_SEP + "⚠️ Manuell gesperrt - Scheduler pausiert.\nNaechste Session:\n" + GetNaechsteSessionInfo());
}
else if(lower == "on") {
Print("AKTION: Setze AutoTrading ON (manuelle Sperre aufgehoben)");
manuellesSperreAktiv = false;
SetAutoTradingState(true);
SendeTelegramFotoURL(SessionOn_Bild_URL, "SESSION GESTARTET\n" + ui_AccountName + "\n" + MSG_SEP + GetAktuelleSessionInfo());
}
else if(lower == "status") {
int tradesPlus = 0, tradesMinus = 0; double profitPlus = 0, profitMinus = 0;
for(int i = 0; i < OrdersTotal(); i++) {
if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) {
if(OrderType() == OP_BUY || OrderType() == OP_SELL) {
double profit = OrderProfit() + OrderSwap() + OrderCommission();
if(profit > 0) { tradesPlus++; profitPlus += profit; } else if(profit < 0) { tradesMinus++; profitMinus += profit; }
}
}
}
int totalTrades = tradesPlus + tradesMinus;
string autoStatus = TerminalInfoInteger(TERMINAL_TRADE_ALLOWED) ? "ON" : "OFF";
double drawdown = BerechneDrawdownVomTagesstart();
string statusMsg = "GOLDY REPORTER STATUS\n";
statusMsg += "Konto: " + ui_AccountName + "\nID: " + IntegerToString(AccountNumber()) + "\nAutoTrading: " + autoStatus + "\n";
statusMsg += "------------------\nOffene Positionen: " + IntegerToString(totalTrades) + "\n";
if(tradesPlus > 0) statusMsg += "Im Plus: " + IntegerToString(tradesPlus) + " (" + FormatGeld(profitPlus) + ")\n";
if(tradesMinus > 0) statusMsg += "Im Minus: " + IntegerToString(tradesMinus) + " (" + FormatGeld(profitMinus) + ")\n";
statusMsg += "------------------\nDrawdown (Tagesstart): -" + DoubleToString(drawdown, 1) + "%\n";
statusMsg += "Equity: " + FormatGeld(AccountEquity()) + " " + g_Währungssymbol + "\nBalance: " + FormatGeld(AccountBalance()) + " " + g_Währungssymbol + "\n\n" + GetZufaelligenSpruch();
SendeTelegramText(statusMsg);
}
else if(lower == "closeall") {
Print("AKTION: Schliesse alle manuellen Positionen");
int closed = 0; int failed = 0; double totalPnL = 0.0;
for(int i = OrdersTotal() - 1; i >= 0; i--) {
if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) {
if(OrderMagicNumber() != 0) continue;
if(OrderType() != OP_BUY && OrderType() != OP_SELL) continue;
double price = (OrderType() == OP_BUY) ? MarketInfo(OrderSymbol(), MODE_BID) : MarketInfo(OrderSymbol(), MODE_ASK);
double pnl = OrderProfit() + OrderSwap() + OrderCommission();
if(OrderClose(OrderTicket(), OrderLots(), price, 10, clrRed)) { closed++; totalPnL += pnl; }
else { failed++; Print("OrderClose Fehler bei Ticket ", OrderTicket(), ": ", GetLastError()); }
}
}
string closeMsg = "CLOSEALL ausgefuehrt\n" + ui_AccountName + "\n" + MSG_SEP;
closeMsg += "Geschlossen: " + IntegerToString(closed) + " manuelle Position(en)\n";
if(failed > 0) closeMsg += "Fehlgeschlagen: " + IntegerToString(failed) + "\n";
if(closed > 0) closeMsg += "Gesamt P/L: " + FormatGeld(totalPnL) + " " + g_Währungssymbol;
else if(failed == 0) closeMsg += "Keine manuellen Positionen offen.";
SendeTelegramText(closeMsg);
}
else if(lower == "b") {
string help = "GOLDY REPORTER - BEFEHLE\n" + MSG_SEP;
help += "Schaltet AutoTrading ein und hebt die manuelle Sperre auf.\n";
help += "/on\n\n";
help += "Stoppt AutoTrading sofort und sperrt den Scheduler.\n";
help += "/off\n\n";
help += "Sendet eine aktuelle Konto-Uebersicht.\n";
help += "/status\n\n";
help += "Schliesst sofort ALLE manuellen Positionen ohne Rueckfrage.\n";
help += "/closeall\n\n";
help += "Zeigt diese Befehls-Liste an.\n";
help += "/b";
SendeTelegramText(help);
}
}
void SchedulerCheck() {
if(!Scheduler_Aktiv) { schedStatus = 0; AktualisiereSchedulerPunkt(); return; }
bool erlaubt = IsAutoTradingErlaubt();
if(erlaubt && !schedWarErlaubt) {
schedStatus = 2; AktualisiereSchedulerPunkt();
if(!manuellesSperreAktiv)
if(MQLInfoInteger(MQL_DLLS_ALLOWED)) if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED)) ToggleAutoTradingButton(true);
if(!manuellesSperreAktiv) SendeTelegramFotoURL(SessionOn_Bild_URL, "SESSION GESTARTET\n" + ui_AccountName + "\n" + MSG_SEP + GetAktuelleSessionInfo());
schedWarErlaubt = true; sessionOffGesendet = false;
} else if(erlaubt && schedWarErlaubt) {
schedStatus = 2; AktualisiereSchedulerPunkt();
if(!manuellesSperreAktiv)
if(MQLInfoInteger(MQL_DLLS_ALLOWED)) if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED)) ToggleAutoTradingButton(true);
} else if(!erlaubt && schedWarErlaubt) {
schedStatus = 1; AktualisiereSchedulerPunkt();
if(Positionen_Schliessen_Bei_Ende) { if(Warten_Bis_Keine_Positionen && HatOffenePositionen()) return; if(Warten_Bis_Keine_Orders && HatPendingOrders()) return; SchliesseAllePositionen(); }
bool kannAusschalten = true; if(Warten_Bis_Keine_Positionen && HatOffenePositionen()) kannAusschalten = false; if(Warten_Bis_Keine_Orders && HatPendingOrders()) kannAusschalten = false;
if(kannAusschalten) {
if(MQLInfoInteger(MQL_DLLS_ALLOWED)) if(TerminalInfoInteger(TERMINAL_TRADE_ALLOWED)) ToggleAutoTradingButton(false);
if(!sessionOffGesendet) { SendeTelegramFotoURL(SessionOff_Bild_URL, "SESSION BEENDET\n" + ui_AccountName + "\n" + MSG_SEP + "Naechste Session:\n" + GetNaechsteSessionInfo()); sessionOffGesendet = true; }
schedWarErlaubt = false;
}
} else { schedStatus = 1; AktualisiereSchedulerPunkt(); }
}
void AktualisiereSchedulerPunkt() {
color punktFarbe; string punktText;
if(schedStatus == 2) { punktFarbe = CLR_GREEN; punktText = "AKTIV"; }
else if(schedStatus == 1) { punktFarbe = CLR_ORANGE; punktText = "GESPERRT"; }
else { punktFarbe = CLR_RED; punktText = "AUS"; }
if(ObjectFind(0, PFX+"SchedPunkt") != -1) { ObjectSetInteger(0, PFX+"SchedPunkt", OBJPROP_BGCOLOR, punktFarbe); ObjectSetInteger(0, PFX+"SchedPunkt", OBJPROP_BORDER_COLOR, punktFarbe); }
if(ObjectFind(0, PFX+"SchedText") != -1) { ObjectSetString(0, PFX+"SchedText", OBJPROP_TEXT, punktText); ObjectSetInteger(0, PFX+"SchedText", OBJPROP_COLOR, punktFarbe); }
}
string GetZufaelligenSpruch() {
MathSrand(GetTickCount());
string sprueche[30] = {
"Disziplin schlägt Emotion . . .",
"Ein Plan gibt Sicherheit . . .",
"Kleine Schritte, großer Erfolg . . .",
"Ruhe bewahrt Kapital . . .",
"Der Markt belohnt Geduld . . .",
"Verluste lehren, Gewinne bestätigen . . .",
"Fokus auf das Wesentliche . . .",
"Jeder Tag ist ein neuer Anfang . . .",
"Strategie vor Spekulation . . .",
"Beständigkeit bringt Ergebnisse . . .",
"Wer wartet, gewinnt oft . . .",
"Klarheit schafft Vertrauen . . .",
"Risiko managen, nicht meiden . . .",
"Heute handeln, morgen ernten . . .",
"Emotionen ausschalten, System folgen . . .",
"Ein Setup, ein Trade . . .",
"Qualität vor Quantität . . .",
"Der beste Trade ist oft keiner . . .",
"Lerne, bevor du verdienst . . .",
"Kapital schützen ist Pflicht . . .",
"Trends folgen, nicht raten . . .",
"Einfachheit siegt im Markt . . .",
"Jeder Fehler ist Fortschritt . . .",
"Bleib ruhig, bleib rational . . .",
"Ziele setzen, Wege finden . . .",
"Erfolg braucht keinen Lärm . . .",
"Konsequent bleiben, Ergebnis kommt . . .",
"Der Markt vergibt nichts . . .",
"Vertrauen in den Prozess . . .",
"Heute besser als gestern . . ."
};
return sprueche[MathRand() % 30];
}
string FormatVPSZeit(datetime brokerTime) {
datetime vpsTime = brokerTime + timeOffset; MqlDateTime dt; TimeToStruct(vpsTime, dt);
return StringFormat("%02d.%02d.%04d %02d:%02d:%02d", dt.day, dt.mon, dt.year, dt.hour, dt.min, dt.sec);
}
//====================== UI HELPERS ==================================
void ObjRect(string n, int x, int y, int w, int h, color c, color b, bool back) {
if(ObjectFind(0, n) == -1) ObjectCreate(0, n, OBJ_RECTANGLE_LABEL, 0, 0, 0);
ObjectSetInteger(0, n, OBJPROP_XDISTANCE, x); ObjectSetInteger(0, n, OBJPROP_YDISTANCE, y);
ObjectSetInteger(0, n, OBJPROP_XSIZE, w); ObjectSetInteger(0, n, OBJPROP_YSIZE, h);
ObjectSetInteger(0, n, OBJPROP_BGCOLOR, c); ObjectSetInteger(0, n, OBJPROP_BORDER_COLOR, b);
ObjectSetInteger(0, n, OBJPROP_BORDER_TYPE, BORDER_FLAT); ObjectSetInteger(0, n, OBJPROP_SELECTABLE, false); ObjectSetInteger(0, n, OBJPROP_BACK, back);
}
void ObjLabel(string n, int x, int y, string t, int fs, color c, string f) {
if(ObjectFind(0, n) == -1) ObjectCreate(0, n, OBJ_LABEL, 0, 0, 0);
ObjectSetInteger(0, n, OBJPROP_XDISTANCE, x); ObjectSetInteger(0, n, OBJPROP_YDISTANCE, y);
ObjectSetString(0, n, OBJPROP_TEXT, t); ObjectSetInteger(0, n, OBJPROP_FONTSIZE, fs);
ObjectSetInteger(0, n, OBJPROP_COLOR, c); ObjectSetString(0, n, OBJPROP_FONT, f);
ObjectSetInteger(0, n, OBJPROP_SELECTABLE, false); ObjectSetInteger(0, n, OBJPROP_BACK, false);
}
void ObjEdit(string n, int x, int y, int w, int h, string txt, color bg, color txtc) {
if(ObjectFind(0, n) == -1) ObjectCreate(0, n, OBJ_EDIT, 0, 0, 0);
ObjectSetInteger(0, n, OBJPROP_XDISTANCE, x); ObjectSetInteger(0, n, OBJPROP_YDISTANCE, y);
ObjectSetInteger(0, n, OBJPROP_XSIZE, w); ObjectSetInteger(0, n, OBJPROP_YSIZE, h);
ObjectSetString(0, n, OBJPROP_TEXT, txt); ObjectSetInteger(0, n, OBJPROP_BGCOLOR, bg);
ObjectSetInteger(0, n, OBJPROP_COLOR, txtc); ObjectSetInteger(0, n, OBJPROP_FONTSIZE, 11);
ObjectSetString(0, n, OBJPROP_FONT, "Courier New"); ObjectSetInteger(0, n, OBJPROP_ALIGN, ALIGN_CENTER);
ObjectSetInteger(0, n, OBJPROP_READONLY, false); ObjectSetInteger(0, n, OBJPROP_SELECTABLE, false); ObjectSetInteger(0, n, OBJPROP_BACK, false);
}
void ObjToggle(string id, int x, int y, bool st) {
ObjRect(PFX+"TogBg_"+id, x, y+4, 42, 22, CLR_INPUT_BG, CLR_BORDER, false);
ObjRect(PFX+"Tog_"+id, x+(st?20:2), y+6, 16, 16, st?CLR_TOGGLE_ON:CLR_TOGGLE_OFF, 0, false);
}
bool IstImMuteFenster() {
if(Stummzeit_Aktivieren == Nein) return false;
string win = Stummzeit_Fenster; StringTrimLeft(win); StringTrimRight(win);
if(StringLen(win) < 5) return false; return CheckZeitInFenster(TimeLocal(), win);
}
//====================== INIT ========================================
int OnInit() {
EventKillTimer();
ui_AccountName = Konto_Bezeichnung; ui_DailyTimeStr = Tagesbericht_Uhrzeit; ui_WeeklyTimeStr = Wochenbericht_Uhrzeit;
ui_DrawdownLimit = Drawdown_Limit_Prozent;
ui_DailyReport = Tagesbericht_Aktiv; ui_WeeklyReport = Wochenbericht_Aktiv;
ui_NewTradeNotif = Benachrichtigung_Neue_Trades; ui_ClosedTradeNotif = Benachrichtigung_Geschlossene_Trades;
g_Währungssymbol = (Währungssymbol == WAHR_EUR) ? "€" : "$";
if(StringLen(Telegram_Bot_Token) < 10 || StringLen(Telegram_Chat_ID) < 5) { Print("Token/ID pruefen!"); return INIT_FAILED; }
// Konto-Isolierung
if(StringLen(RoboForex_KontoNr) > 0) {
g_FileSuffix = "_" + RoboForex_KontoNr;
if(IntegerToString(AccountNumber()) != RoboForex_KontoNr) {
Alert("ACHTUNG: Eingestellte RoboForex Konto-Nr. (", RoboForex_KontoNr, ") stimmt nicht mit dem angemeldeten Konto (", AccountNumber(), ") überein! Bitte prüfen.");
}
}
{ datetime jetzt = TimeLocal(); int dow = TimeDayOfWeek(jetzt); if(dow == 0) dow = 7;
int tageZurueck = (dow == 1) ? 0 : (dow - 1); MqlDateTime dtMo; TimeToStruct(jetzt - tageZurueck * 86400, dtMo);
dtMo.hour = 0; dtMo.min = 0; dtMo.sec = 0; wocheStartZeit = StructToTime(dtMo);
equityStartWoche = AccountEquity(); wocheResetErledigt = true; }
EA_StartZeit = TimeCurrent(); timeOffset = (int)(TimeLocal() - TimeCurrent());
schedWarErlaubt = IsAutoTradingErlaubt(); sessionOffGesendet = false;
// ✅ CHART KOMPLETT SCHWARZ
ChartSetInteger(0, CHART_COLOR_BACKGROUND, 0x000000);
ChartSetInteger(0, CHART_COLOR_FOREGROUND, 0x000000);
ChartSetInteger(0, CHART_COLOR_CANDLE_BULL, 0x000000);
ChartSetInteger(0, CHART_COLOR_CANDLE_BEAR, 0x000000);
ChartSetInteger(0, CHART_COLOR_CHART_LINE, 0x000000);
ChartSetInteger(0, CHART_COLOR_GRID, 0x000000);
ChartSetInteger(0, CHART_COLOR_VOLUME, 0x000000);
ChartSetInteger(0, CHART_COLOR_ASK, 0x000000);
ChartSetInteger(0, CHART_COLOR_BID, 0x000000);
ChartSetInteger(0, CHART_COLOR_LAST, 0x000000);
ChartSetInteger(0, CHART_COLOR_STOP_LEVEL, 0x000000);
ChartSetInteger(0, CHART_SHOW_GRID, false);
ChartSetInteger(0, CHART_SHOW_VOLUMES, false);
ChartSetInteger(0, CHART_SHOW_BID_LINE, false);
ChartSetInteger(0, CHART_SHOW_ASK_LINE, false);
ChartSetInteger(0, CHART_SHOW_LAST_LINE, false);
ChartSetInteger(0, CHART_SHOW_OHLC, false);
ChartRedraw();
Comment(""); ObjectsDeleteAll(0, PFX); LadeGesendeteTickets(); VormerkenAlleHistorischenTrades();
ObjRect(PFX+"BG", 0, 0, PW+20, PH+20, CLR_BG, 0, true); ObjRect(PFX+"Glow", -5, -5, PW+30, PH+30, 0x1A1500, 0, true);
ObjRect(PFX+"Border", 0, 0, PW+20, PH+20, CLR_GOLD, CLR_GOLD, false); ObjRect(PFX+"Inner", 2, 2, PW+16, PH+16, CLR_BG, 0, false);
ObjRect(PFX+"Header", 2, 2, PW+16, 50, CLR_GOLD, CLR_GOLD, false);
ObjLabel(PFX+"Title", 25, 15, "GOLDY REPORTER", 16, clrBlack, "Arial Black");
ObjLabel(PFX+"Ver", PW-70, 15, "v1.0", 12, clrBlack, "Arial Bold");
int y = 65;
ObjLabel(PFX+"Lbl_Konto", COL_L, y, "KONTO-BEZEICHNUNG", 11, CLR_GOLD, "Arial Bold"); y += 22;
ObjEdit(PFX+"Edit_Konto", COL_L, y, 300, 22, ui_AccountName, CLR_EDIT_BG, CLR_GREEN); y += 40;
ObjLabel(PFX+"Lbl_Left", COL_L, y, "BERICHTE & WARNUNGEN", 12, CLR_GOLD, "Arial Bold"); y += 30;
ObjLabel(PFX+"L_DailyOn", COL_L, y, "Tagesbericht:", 11, CLR_GOLD, "Arial"); ObjToggle("DailyReport", TOGGLE_X, y, ui_DailyReport); y += ROW_H;
ObjLabel(PFX+"L_DailyTime", COL_L, y, "Uhrzeit:", 11, CLR_TEXT_DIM, "Arial"); ObjEdit(PFX+"In_Daily", INPUT_X, y, 70, 22, ui_DailyTimeStr, CLR_EDIT_BG, CLR_GREEN); y += ROW_H;
ObjLabel(PFX+"L_WeekOn", COL_L, y, "Wochenbericht:", 11, CLR_GOLD, "Arial"); ObjToggle("WeeklyReport", TOGGLE_X, y, ui_WeeklyReport); y += ROW_H;
ObjLabel(PFX+"L_WeekTime", COL_L, y, "Uhrzeit:", 11, CLR_TEXT_DIM, "Arial"); ObjEdit(PFX+"In_Weekly", INPUT_X, y, 70, 22, ui_WeeklyTimeStr, CLR_EDIT_BG, CLR_GREEN); y += ROW_H;
ObjLabel(PFX+"L_Draw", COL_L, y, "Drawdown-Limit:", 11, CLR_GOLD, "Arial"); ObjEdit(PFX+"In_Draw", INPUT_X, y, 70, 22, DoubleToString(ui_DrawdownLimit, 0), CLR_EDIT_BG, CLR_GREEN); ObjToggle("DrawdownWarn", TOGGLE_X, y, ui_DrawdownWarn); y += ROW_H;
ObjLabel(PFX+"L_NewTrade", COL_L, y, "Neue Trades melden:", 11, CLR_GOLD, "Arial"); ObjToggle("NewTradeNotif", TOGGLE_X, y, ui_NewTradeNotif); y += ROW_H;
ObjLabel(PFX+"L_ClosedTrade", COL_L, y, "Abgeschlossene Trades melden:", 11, CLR_GOLD, "Arial"); ObjToggle("ClosedTradeNotif", TOGGLE_X, y, ui_ClosedTradeNotif); y += ROW_H;
ObjLabel(PFX+"L_Sched", COL_L, y, "Scheduler:", 11, CLR_GOLD, "Arial");
ObjRect(PFX+"SchedPunkt", TOGGLE_X, y+3, 12, 12, CLR_RED, CLR_RED, false);
ObjLabel(PFX+"SchedText", TOGGLE_X+18, y, "AUS", 11, CLR_RED, "Courier New"); y += ROW_H + 10;
ui_BoxY = y; int boxW = PW - 50;
ObjRect(PFX+"Box1", COL_L, ui_BoxY, boxW, 150, CLR_PANEL, CLR_TRANSPARENT, false);
ObjLabel(PFX+"Box1T", COL_L+15, ui_BoxY+12, "DIESE WOCHE - PERFORMANCE", 11, CLR_GOLD, "Arial Bold");
ObjRect(PFX+"Box2", COL_L, ui_BoxY+165, boxW, 150, CLR_PANEL, CLR_TRANSPARENT, false);
ObjLabel(PFX+"Box2T", COL_L+15, ui_BoxY+177, "HANDELSTAGE NAECHSTE WOCHE", 11, CLR_GOLD, "Arial Bold");
CreateBoxContent();
equityStartTag = AccountEquity();
ResetTagesStatistik();
UpdateDynamicAreas();
AktualisiereSchedulerPunkt();
Print("Goldy Reporter V1.0 geladen.");
int timerSec = MathMax(Fernsteuerung_Abfrage_Sekunden, 5);
if(!EventSetTimer(timerSec)) { Print("FEHLER: Timer konnte nicht gesetzt werden!"); return INIT_FAILED; }
SendeTelegramFotoURL(Startup_Bild_URL, "Goldy Reporter v1.0 aktiv: " + ui_AccountName + (StringLen(g_FileSuffix)>0 ? " | Konto: " + RoboForex_KontoNr : ""));
return INIT_SUCCEEDED;
}
void OnDeinit(const int reason) {
SpeichereGesendeteTickets();
ObjectsDeleteAll(0, PFX);
Comment("");
EventKillTimer();
}
void OnTimer() { CheckRemoteCommands(); }
void CreateBoxContent() {
ObjLabel(PFX+"St1", COL_L+15, ui_BoxY+38, "Profit:", 11, CLR_TEXT, "Arial");
ObjLabel(PFX+"St1V", COL_L+320, ui_BoxY+38, "+0.00 " + g_Währungssymbol, 11, CLR_GREEN, "Courier New");
ObjLabel(PFX+"St2", COL_L+15, ui_BoxY+60, "Trades:", 11, CLR_TEXT, "Arial");
ObjLabel(PFX+"St2V", COL_L+320, ui_BoxY+60, "0 Win / 0 Loss", 11, CLR_TEXT, "Courier New");
ObjLabel(PFX+"St3", COL_L+15, ui_BoxY+82, "Drawdown:", 11, CLR_TEXT, "Arial");
ObjLabel(PFX+"St3V", COL_L+320, ui_BoxY+82, "-0.0%", 11, CLR_ORANGE, "Courier New");
string d[5] = {"Mo","Di","Mi","Do","Fr"};
for(int k = 0; k < 5; k++) { int lineY = ui_BoxY + 177 + 38 + (k * 20); ObjLabel(PFX+"P_"+k, COL_L+15, lineY, d[k]+", 00.00.", 11, CLR_TEXT, "Arial"); ObjLabel(PFX+"PS_"+k, COL_L+320, lineY, "OK", 11, CLR_GREEN, "Courier New"); }
}
void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam) {
if(id == CHARTEVENT_OBJECT_CLICK && StringFind(sparam, PFX+"Tog_") == 0) {
string base = StringSubstr(sparam, StringLen(PFX+"Tog_"));
bool st = !(ObjectGetInteger(0, PFX+"TogBg_"+base, OBJPROP_BGCOLOR) == CLR_TOGGLE_ON);
ObjectSetInteger(0, PFX+"TogBg_"+base, OBJPROP_BGCOLOR, st ? CLR_TOGGLE_ON : CLR_TOGGLE_OFF);
int bx = (int)ObjectGetInteger(0, PFX+"TogBg_"+base, OBJPROP_XDISTANCE);
ObjectSetInteger(0, PFX+"Tog_"+base, OBJPROP_XDISTANCE, bx + (st ? 20 : 2));
if(base=="DailyReport") ui_DailyReport = st; else if(base=="DrawdownWarn") ui_DrawdownWarn = st;
else if(base=="WeeklyReport") ui_WeeklyReport = st; else if(base=="NewTradeNotif") ui_NewTradeNotif = st;
else if(base=="ClosedTradeNotif") ui_ClosedTradeNotif = st;
}
if(id == CHARTEVENT_OBJECT_ENDEDIT) {
string val = ObjectGetString(0, sparam, OBJPROP_TEXT);
if(StringFind(sparam, "Edit_Konto") != -1) ui_AccountName = val;
else if(StringFind(sparam, "In_Daily") != -1) ui_DailyTimeStr = val;
else if(StringFind(sparam, "In_Draw") != -1) ui_DrawdownLimit = StringToDouble(val);
else if(StringFind(sparam, "In_Weekly") != -1) ui_WeeklyTimeStr = val;
}
}
//====================== ONTICK ======================================
void OnTick() {
double eq = AccountEquity();
if(eq > maxEquityHeute) maxEquityHeute = eq;
if(eq < minEquityHeute) minEquityHeute = eq;
SchedulerCheck();
if(ui_DrawdownWarn) PruefeDrawdown(eq);
if(ui_NewTradeNotif) PruefeNeueTrades();
if(ui_ClosedTradeNotif) PruefeGeschlosseneTrades();
if(ui_DailyReport) PruefeTagesbericht();
if(ui_WeeklyReport) PruefeWochenbericht();
if(Tagesziel_Benachrichtigung && Tagesziel_Betrag > 0) PruefeTagesziel();
static datetime lastUI = 0; datetime now = TimeLocal();
if(now - lastUI >= 60) { UpdateDynamicAreas(); lastUI = now; }
}
//====================== RESTLICHE FUNKTIONEN ========================
void ResetTagesStatistik() {
equityStartTag = AccountEquity(); maxEquityHeute = equityStartTag; minEquityHeute = equityStartTag;
berichtGesendetHeute = false; drawdownWarnungGesendet = false;
ziel25Erreicht = false; ziel50Erreicht = false; ziel75Erreicht = false; ziel100Erreicht = false;
zielHoechsterWertWaehrendMute = 0; zielMuteNachrichtGesendet = false;
int dow = TimeDayOfWeek(TimeLocal()); if(dow == 0) dow = 7;
if(dow == 1 && !wocheResetErledigt) { equityStartWoche = AccountEquity(); MqlDateTime dtMo; TimeToStruct(TimeLocal(), dtMo); dtMo.hour = 0; dtMo.min = 0; dtMo.sec = 0; wocheStartZeit = StructToTime(dtMo); wocheResetErledigt = true; wochenberichtGesendet = false; }
if(dow == 2) wocheResetErledigt = false;
}
double BerechneDrawdownVomTagesstart() { if(equityStartTag <= 0) return 0; double dd = ((equityStartTag - minEquityHeute) / equityStartTag) * 100.0; return(dd > 0 ? dd : 0); }
void PruefeDrawdown(double eq) {
double dd = BerechneDrawdownVomTagesstart();
if(dd >= ui_DrawdownLimit && !drawdownWarnungGesendet) { SendeTelegramFotoURL(Drawdown_Bild_URL, "DRAWDOWN fuer " + ui_AccountName + "\n" + MSG_SEP + "DRAWDOWN: " + DoubleToString(dd, 1) + "%"); drawdownWarnungGesendet = true; }
else if(dd < ui_DrawdownLimit * 0.8) drawdownWarnungGesendet = false;
}
void PruefeTagesziel() {
double tagesProfit = 0; datetime heuteStart = StringToTime(TimeToString(TimeLocal(), TIME_DATE) + " 00:00");
for(int k = OrdersHistoryTotal()-1; k >= 0; k--) { if(OrderSelect(k, SELECT_BY_POS, MODE_HISTORY) && OrderSymbol() == Symbol() && OrderCloseTime() >= heuteStart) tagesProfit += OrderProfit() + OrderSwap() + OrderCommission(); }
double zielInNativ = (Konto_Typ == Pro_Cent) ? Tagesziel_Betrag : (Tagesziel_Betrag / 100.0);
if(zielInNativ <= 0) return;
double prozent = (tagesProfit / zielInNativ) * 100.0;
if(prozent >= 25.0 && !ziel25Erreicht) { SendeTageszielNachricht(25, tagesProfit); ziel25Erreicht = true; }
if(prozent >= 50.0 && !ziel50Erreicht) { SendeTageszielNachricht(50, tagesProfit); ziel50Erreicht = true; }
if(prozent >= 75.0 && !ziel75Erreicht) { SendeTageszielNachricht(75, tagesProfit); ziel75Erreicht = true; }
if(prozent >= 100.0 && !ziel100Erreicht) { SendeTageszielNachricht(100, tagesProfit); ziel100Erreicht = true; }
if(IstImMuteFenster()) { if(prozent > zielHoechsterWertWaehrendMute) zielHoechsterWertWaehrendMute = prozent; }
else if(!IstImMuteFenster() && zielHoechsterWertWaehrendMute > 0 && !zielMuteNachrichtGesendet) {
int stufe = 0;
if(zielHoechsterWertWaehrendMute >= 100) stufe = 100; else if(zielHoechsterWertWaehrendMute >= 75) stufe = 75; else if(zielHoechsterWertWaehrendMute >= 50) stufe = 50; else if(zielHoechsterWertWaehrendMute >= 25) stufe = 25;
if(stufe > 0) { SendeTageszielNachricht(stufe, tagesProfit); zielMuteNachrichtGesendet = true; zielHoechsterWertWaehrendMute = 0; }
}
}
void SendeTageszielNachricht(int prozent, double profit) {
string bildURL = "";
if(prozent == 25) bildURL = Ziel25_Bild_URL; else if(prozent == 50) bildURL = Ziel50_Bild_URL; else if(prozent == 75) bildURL = Ziel75_Bild_URL; else if(prozent == 100) bildURL = Ziel100_Bild_URL;
string msg = ui_AccountName + "\nTAGESZIEL ZU " + IntegerToString(prozent) + "% ERREICHT! Aktueller Profit: " + FormatGeld(profit) + " " + g_Währungssymbol + "\nTagesziel: " + FormatGeld(Tagesziel_Betrag) + " " + g_Währungssymbol + "\n" + GetZufaelligenSpruch();
SendeTelegramFotoURL(bildURL, msg);
}
void PruefeNeueTrades() {
if(IstImMuteFenster() || Stil_Neuer_Trade == KEINE) return;
int tot = OrdersTotal();
for(int k = tot - 1; k >= 0; k--) {
if(OrderSelect(k, SELECT_BY_POS, MODE_TRADES) && OrderSymbol() == Symbol()) {
int ot = OrderType(); if(ot != OP_BUY && ot != OP_SELL) continue;
string t = IntegerToString(OrderTicket()); if(OrderOpenTime() < EA_StartZeit) continue;
if(!IstInListe(TPR_sentOpen, t)) {
string tp = (ot == OP_BUY) ? "BUY" : "SELL"; string zeit = FormatVPSZeit(OrderOpenTime());
string msg = "", bildURL = "";
if(Stil_Neuer_Trade == Bild_und_Nachricht || Stil_Neuer_Trade == Nur_Nachricht) msg = "NEUER TRADE\n" + ui_AccountName + "\n" + MSG_SEP + "Ordernummer: " + t + "\n" + zeit + "\n" + tp + "\n" + DoubleToString(OrderLots(), 2) + " Lot\n" + GetZufaelligenSpruch();
if(Stil_Neuer_Trade == Bild_und_Nachricht || Stil_Neuer_Trade == Nur_Bild) bildURL = NewTrade_Bild_URL;
if(SendeTelegramFotoURL(bildURL, msg)) { TPR_sentOpen = FuegeZuListe(TPR_sentOpen, t); SpeichereGesendeteTickets(); }
}
}
}
}
void PruefeGeschlosseneTrades() {
if(IstImMuteFenster()) return;
double basis = BerechneInvestmentBasis(); int tot = OrdersHistoryTotal(); int st = MathMax(0, tot - 50);
for(int k = st; k < tot; k++) {
if(OrderSelect(k, SELECT_BY_POS, MODE_HISTORY)) {
int ot = OrderType(); if(ot != OP_BUY && ot != OP_SELL) continue;
string t = IntegerToString(OrderTicket()); if(OrderCloseTime() < EA_StartZeit) continue;
if(!IstInListe(TPR_sentClosed, t)) {
string tp = (ot == OP_BUY) ? "BUY" : "SELL"; double g = OrderProfit() + OrderSwap() + OrderCommission();
string openZeit = FormatVPSZeit(OrderOpenTime()); string closeZeit = FormatVPSZeit(OrderCloseTime());
bool istWin = (g > 0); ENUM_NOTIF_STIL aktuellerStil = istWin ? Stil_Gewinn_Trade : Stil_Verlust_Trade;
if(aktuellerStil == KEINE) continue;
string msg = "", bildURL = "";
if(aktuellerStil == Bild_und_Nachricht || aktuellerStil == Nur_Nachricht) {
msg = "TRADE GESCHLOSSEN\n" + ui_AccountName + "\n" + MSG_SEP + "Ordernummer: " + t + "\nEroeffnet: " + openZeit + " @ " + DoubleToString(OrderOpenPrice(), Digits) + "\nGeschlossen: " + closeZeit + " @ " + DoubleToString(OrderClosePrice(), Digits) + "\n" + tp + "\n" + DoubleToString(OrderLots(), 2) + " Lot\nDrawdown: -" + DoubleToString(BerechneDrawdownVomTagesstart(), 1) + "%\nProfit: " + FormatGeld(g) + " " + g_Währungssymbol + "\n";
if(g > 0) msg += "\nGewinn vom Investment: " + FormatRendite(g, basis) + "\nBalabum Balla Baeng - Trade lief perfekt, Konto lacht.";
}
if(aktuellerStil == Bild_und_Nachricht || aktuellerStil == Nur_Bild) bildURL = istWin ? Winning_Bild_URL : Loss_Bild_URL;
if(SendeTelegramFotoURL(bildURL, msg)) { TPR_sentClosed = FuegeZuListe(TPR_sentClosed, t); SpeichereGesendeteTickets(); }
}
}
}
}
void PruefeTagesbericht() {
if(TimeDay(TimeLocal()) != TimeDay(letzterBerichtTag)) { ResetTagesStatistik(); letzterBerichtTag = TimeLocal(); }
if(berichtGesendetHeute) return;
int targetH = (int)StringToInteger(StringSubstr(ui_DailyTimeStr, 0, 2)); int targetM = (int)StringToInteger(StringSubstr(ui_DailyTimeStr, 3, 2));
int bh = TimeHour(TimeLocal()); if(bh < 0) bh += 24; if(bh >= 24) bh -= 24;
int dayOfWeek = TimeDayOfWeek(TimeLocal());
bool tagesberichtErlaubt = false;
if(Tagesbericht_Wochentage == Mo_So) tagesberichtErlaubt = true;
else if(Tagesbericht_Wochentage == Mo_Fr && dayOfWeek >= 1 && dayOfWeek <= 5) tagesberichtErlaubt = true;
if(bh == targetH && TimeMinute(TimeLocal()) == targetM && tagesberichtErlaubt) {
berichtGesendetHeute = true; double basis = BerechneInvestmentBasis();
double tagesProfit=0, wochenProfit=0, gesamtProfit=0; int heuteWin=0, heuteLoss=0;
datetime heuteStart = StringToTime(TimeToString(TimeLocal(), TIME_DATE) + " 00:00");
for(int k = OrdersHistoryTotal()-1; k >= 0; k--) {
if(OrderSelect(k, SELECT_BY_POS, MODE_HISTORY) && OrderSymbol() == Symbol()) {
double profit = OrderProfit() + OrderSwap() + OrderCommission(); datetime ct = OrderCloseTime();
gesamtProfit += profit; if(ct >= wocheStartZeit) wochenProfit += profit;
if(ct >= heuteStart) { tagesProfit += profit; if(profit > 0) heuteWin++; else if(profit < 0) heuteLoss++; }
}
}
string msg = "TAGESBERICHT\n" + ui_AccountName + "\n" + MSG_SEP + "Tages P/L: " + FormatGeld(tagesProfit) + " " + g_Währungssymbol + "\nTages Rendite: " + FormatRendite(tagesProfit, basis) + " vom Investment\nWochen P/L: " + FormatGeld(wochenProfit) + " " + g_Währungssymbol + "\nWochen Rendite: " + FormatRendite(wochenProfit, basis) + " vom Investment\nGesamt P/L: " + FormatGeld(gesamtProfit) + " " + g_Währungssymbol + "\nGesamt Rendite: " + FormatRendite(gesamtProfit, basis) + " vom Investment\n" + MSG_SEP + "Trades heute: " + IntegerToString(heuteWin + heuteLoss) + " (" + IntegerToString(heuteWin) + "W/" + IntegerToString(heuteLoss) + "L)\n";
msg += "Aktuelle Equity: " + FormatGeld(AccountEquity()) + " " + g_Währungssymbol;
SendeTelegramFotoURL(DayReport_Bild_URL, msg);
}
}
void PruefeWochenbericht() {
int cd = TimeDayOfWeek(TimeLocal());
int bh = TimeHour(TimeLocal()); int bm = TimeMinute(TimeLocal());
int targetH = (int)StringToInteger(StringSubstr(ui_WeeklyTimeStr, 0, 2)); int targetM = (int)StringToInteger(StringSubstr(ui_WeeklyTimeStr, 3, 2));
bool wochenberichtErlaubt = false;
if(Wochenbericht_Tag == Nur_Freitag && cd == 5) wochenberichtErlaubt = true;
else if(Wochenbericht_Tag == Nur_Sonntag && cd == 0) wochenberichtErlaubt = true;
else if(Wochenbericht_Tag == Fr_Und_So && (cd == 5 || cd == 0)) wochenberichtErlaubt = true;
if(wochenberichtErlaubt && bh == targetH && bm == targetM && !wochenberichtGesendet) {
wochenberichtGesendet = true; double basis = BerechneInvestmentBasis(); double p = 0; int w = 0, l = 0;
for(int k = OrdersHistoryTotal()-1; k >= 0; k--) {
if(OrderSelect(k, SELECT_BY_POS, MODE_HISTORY) && OrderCloseTime() >= wocheStartZeit && OrderSymbol() == Symbol()) {
double pr = OrderProfit() + OrderSwap() + OrderCommission(); p += pr; if(pr > 0) w++; else if(pr < 0) l++;
}
}
string msg = "WOCHENBERICHT\n" + ui_AccountName + "\n" + MSG_SEP + "Profit: " + FormatGeld(p) + " " + g_Währungssymbol + "\nWochen Rendite: " + FormatRendite(p, basis) + " vom Investment\nTrades: " + IntegerToString(w) + " Win / " + IntegerToString(l) + " Loss\n";
msg += "Naechste Woche:\n" + GetHandelstageNaechsteWoche();
SendeTelegramFotoURL(WeeklyReport_Bild_URL, msg);
}
if(cd == 6) { wochenberichtGesendet = false; }
}
string GetHandelstageNaechsteWoche() {
datetime jetzt = TimeLocal(); int wt = TimeDayOfWeek(jetzt); if(wt == 0) wt = 7;
int tb = (wt == 1) ? 7 : (8 - wt); datetime mo = jetzt + (tb * 86400);
string t[5] = {"Mo","Di","Mi","Do","Fr"}, r = "";
for(int k = 0; k < 5; k++) { datetime tg = mo + (k * 86400); r += t[k] + ", " + StringFormat("%02d.%02d.", TimeDay(tg), TimeMonth(tg)) + " OK\n"; }
return r;
}
void UpdateDynamicAreas() {
double wp = 0; int ww = 0, wl = 0;
for(int k = OrdersHistoryTotal()-1; k >= 0; k--) {
if(OrderSelect(k, SELECT_BY_POS, MODE_HISTORY) && OrderCloseTime() >= wocheStartZeit && OrderSymbol() == Symbol()) {
double pr = OrderProfit() + OrderSwap() + OrderCommission(); wp += pr; if(pr > 0) ww++; else if(pr < 0) wl++;
}
}
ObjectSetString(0, PFX+"St1V", OBJPROP_TEXT, FormatGeld(wp) + " " + g_Währungssymbol);
ObjectSetInteger(0, PFX+"St1V", OBJPROP_COLOR, (long)(wp >= 0 ? CLR_GREEN : CLR_ORANGE));
ObjectSetString(0, PFX+"St2V", OBJPROP_TEXT, IntegerToString(ww) + " Win / " + IntegerToString(wl) + " Loss");
ObjectSetString(0, PFX+"St3V", OBJPROP_TEXT, "-" + DoubleToString(BerechneDrawdownVomTagesstart(), 1) + "%");
string d[5] = {"Mo","Di","Mi","Do","Fr"}; datetime jetzt = TimeLocal(); int wt = TimeDayOfWeek(jetzt); if(wt == 0) wt = 7;
int tb = (wt == 1) ? 7 : (8 - wt); datetime mo = jetzt + (tb * 86400);
for(int k = 0; k < 5; k++) { datetime tg = mo + (k * 86400); ObjectSetString(0, PFX+"P_"+k, OBJPROP_TEXT, d[k] + ", " + StringFormat("%02d.%02d.", TimeDay(tg), TimeMonth(tg))); }
}
//+------------------------------------------------------------------+
