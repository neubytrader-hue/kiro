//+------------------------------------------------------------------+
//|                                       Goldy_Screenshot_V2_0.mq4  |
//|                                       GOLDY Screenshot V 2.0     |
//|                                       Copyright 2026, Alex       |
//+------------------------------------------------------------------+
//|  CHANGES V2.0 (vs V1.0):                                          |
//|  - Sendet das Chart-Bild DIREKT an Telegram                       |
//|    (vorher: nur als Datei in den Common-Ordner abgelegt)          |
//|  - Neue Telegram Inputs (Bot Token + Chat ID)                     |
//|  - sendPhoto via multipart/form-data (mit Bild-Anhang)            |
//|  - Schreibt Done-Datei als Bestaetigung an den GOLDY AI TRADER    |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Alex"
#property version   "2.00"
#property description "GOLDY Screenshot V 2.0"
#property description "Macht Chart-Screenshot auf Anfrage und sendet ihn an Telegram"
#property strict

//+------------------------------------------------------------------+
//| EINGABE-PARAMETER                                                |
//+------------------------------------------------------------------+
input string   __Tag_Header        = "==== ALLGEMEIN ====";
input string   Inst_Bezeichnung    = "Wave Chart";

input string   __Telegram_Header   = "==== TELEGRAM ====";
input string   Bot_Token           = "DEIN_TOKEN";
input string   Chat_ID             = "";
input string   Caption_Text        = "";   // optional, leer = ohne Text unter dem Bild

input string   __Screenshot_Header = "==== SCREENSHOT ====";
input int      Screenshot_Breite   = 1920;
input int      Screenshot_Hoehe    = 1080;

input string   __Bridge_Header     = "==== BRIDGE (zum GOLDY AI TRADER) ====";
input int      Pruef_Intervall_Ms  = 500;
input string   Request_Datei       = "Goldy_Shared\\screenshot_request.txt";
input string   Done_Datei          = "Goldy_Shared\\screenshot_done.txt";

//+------------------------------------------------------------------+
//| GLOBALE VARIABLEN                                                |
//+------------------------------------------------------------------+
datetime g_letzter_screenshot = 0;
int      g_screenshots_gesamt = 0;

//+------------------------------------------------------------------+
//| OnInit                                                            |
//+------------------------------------------------------------------+
int OnInit()
{
   EventSetMillisecondTimer(Pruef_Intervall_Ms);

   Print("====================================");
   Print("GOLDY Screenshot V 2.0 gestartet");
   Print("Bezeichnung    : ", Inst_Bezeichnung);
   Print("Bild-Groesse   : ", Screenshot_Breite, " x ", Screenshot_Hoehe);
   Print("Pruef-Intervall: ", Pruef_Intervall_Ms, " ms");
   Print("Request-Datei  : ", Request_Datei);
   Print("Done-Datei     : ", Done_Datei);
   if(StringLen(Bot_Token) < 10 || StringLen(Chat_ID) < 3)
      Print("WARNUNG: Bot_Token oder Chat_ID nicht gesetzt!");
   else
      Print("Telegram OK    : Token+ChatID konfiguriert");
   Print("====================================");

   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| OnDeinit                                                          |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   EventKillTimer();
   Print("GOLDY Screenshot V 2.0 beendet. Screenshots gesamt: ", g_screenshots_gesamt);
}

//+------------------------------------------------------------------+
//| OnTimer - Polling auf Request-Datei                              |
//+------------------------------------------------------------------+
void OnTimer()
{
   if(!FileIsExist(Request_Datei, FILE_COMMON))
      return;

   Print(">>> BRIDGE: Request empfangen, mache Screenshot...");

   uchar bild_daten[];
   bool screenshot_ok = ScreenshotErstellen(bild_daten);

   bool telegram_ok = false;
   if(screenshot_ok)
   {
      string filename = "chart_" + IntegerToString((int)TimeCurrent()) + ".png";
      telegram_ok = SendePhotoMultipart(bild_daten, filename);

      if(telegram_ok)
      {
         g_screenshots_gesamt++;
         g_letzter_screenshot = TimeCurrent();
         Print("Bridge: Screenshot #", g_screenshots_gesamt, " erfolgreich an Telegram gesendet");
      }
      else
         Print("Bridge: FEHLER - Telegram-Upload fehlgeschlagen");
   }
   else
      Print("Bridge: FEHLER - Screenshot konnte nicht erstellt werden");

   // Done-Datei IMMER schreiben (auch bei Fehler), damit Goldy nicht ewig wartet
   DoneSchreiben(telegram_ok);

   // Request-Datei loeschen
   if(FileIsExist(Request_Datei, FILE_COMMON))
      FileDelete(Request_Datei, FILE_COMMON);
}

void OnTick() { }

//+------------------------------------------------------------------+
//| SCREENSHOT ERSTELLEN                                             |
//| Speichert Chart-Bild zuerst lokal in MQL4\Files\, liest es als   |
//| Byte-Array ein und gibt es zurueck. Datei wird wieder geloescht. |
//+------------------------------------------------------------------+
bool ScreenshotErstellen(uchar &bild_daten[])
{
   string temp_datei = "goldy_screenshot_temp.png";

   if(!ChartScreenShot(0, temp_datei, Screenshot_Breite, Screenshot_Hoehe, ALIGN_RIGHT))
   {
      Print("ChartScreenShot fehlgeschlagen. Error=", GetLastError());
      return false;
   }

   int fh = FileOpen(temp_datei, FILE_BIN | FILE_READ);
   if(fh == INVALID_HANDLE)
   {
      Print("Kann Screenshot-Datei nicht oeffnen. Error=", GetLastError());
      return false;
   }

   int fsize = (int)FileSize(fh);
   if(fsize <= 0)
   {
      FileClose(fh);
      Print("Screenshot-Datei ist leer");
      return false;
   }

   ArrayResize(bild_daten, fsize);
   FileReadArray(fh, bild_daten, 0, fsize);
   FileClose(fh);

   FileDelete(temp_datei);
   return true;
}

//+------------------------------------------------------------------+
//| DONE-DATEI SCHREIBEN (Bestaetigung an GOLDY AI TRADER)           |
//+------------------------------------------------------------------+
void DoneSchreiben(bool erfolg)
{
   int fh = FileOpen(Done_Datei, FILE_WRITE | FILE_TXT | FILE_COMMON);
   if(fh == INVALID_HANDLE)
   {
      Print("WARNUNG: Done-Datei nicht schreibbar. Error=", GetLastError());
      return;
   }
   FileWrite(fh, erfolg ? "OK" : "FAIL");
   FileWrite(fh, "ts=", (int)TimeCurrent());
   FileClose(fh);
}

//+------------------------------------------------------------------+
//| TELEGRAM sendPhoto via multipart/form-data                       |
//| Sendet eine PNG-Datei (binaer) als Anhang an die Telegram-API.   |
//+------------------------------------------------------------------+
bool SendePhotoMultipart(uchar &bild_daten[], string filename)
{
   if(StringLen(Bot_Token) < 10 || StringLen(Chat_ID) < 3)
   {
      Print("Telegram: Bot_Token oder Chat_ID fehlt - Upload abgebrochen");
      return false;
   }

   string CRLF     = CharToString(13) + CharToString(10);
   string boundary = "----GoldyShotBoundary" + IntegerToString(GetTickCount());
   string url      = "https://api.telegram.org/bot" + Bot_Token + "/sendPhoto";
   string headers  = "Content-Type: multipart/form-data; boundary=" + boundary + CRLF;

   // Header-Teil (Text vor den Bild-Bytes)
   string pre_str = "--" + boundary + CRLF;
   pre_str += "Content-Disposition: form-data; name=\"chat_id\"" + CRLF + CRLF;
   pre_str += Chat_ID + CRLF;

   if(StringLen(Caption_Text) > 0)
   {
      pre_str += "--" + boundary + CRLF;
      pre_str += "Content-Disposition: form-data; name=\"caption\"" + CRLF + CRLF;
      pre_str += Caption_Text + CRLF;
   }

   pre_str += "--" + boundary + CRLF;
   pre_str += "Content-Disposition: form-data; name=\"photo\"; filename=\"" + filename + "\"" + CRLF;
   pre_str += "Content-Type: image/png" + CRLF + CRLF;

   // Footer-Teil (Text nach den Bild-Bytes)
   string post_str = CRLF + "--" + boundary + "--" + CRLF;

   // String -> uchar[]
   uchar pre_bytes[], post_bytes[];
   int pre_len  = StringLen(pre_str);
   int post_len = StringLen(post_str);
   ArrayResize(pre_bytes, pre_len);
   ArrayResize(post_bytes, post_len);
   StringToCharArray(pre_str,  pre_bytes,  0, pre_len,  CP_UTF8);
   StringToCharArray(post_str, post_bytes, 0, post_len, CP_UTF8);

   // Gesamten Body zusammensetzen
   int img_len = ArraySize(bild_daten);
   uchar body[];
   ArrayResize(body, pre_len + img_len + post_len);
   for(int i = 0; i < pre_len;  i++) body[i] = pre_bytes[i];
   for(int j = 0; j < img_len;  j++) body[pre_len + j] = bild_daten[j];
   for(int k = 0; k < post_len; k++) body[pre_len + img_len + k] = post_bytes[k];

   // WebRequest absenden
   uchar res[]; string res_h;
   int code = WebRequest("POST", url, headers, 30000, body, res, res_h);

   if(code == 200)
   {
      Print("Telegram: Foto gesendet (", img_len, " Bytes Bild + ",
            (pre_len + post_len), " Bytes Header)");
      return true;
   }

   string resp = CharArrayToString(res, 0, -1, CP_UTF8);
   if(StringLen(resp) > 250) resp = StringSubstr(resp, 0, 250) + "...";
   Print("Telegram FEHLER HTTP=", code, " | Antwort: ", resp);
   return false;
}
//+------------------------------------------------------------------+
