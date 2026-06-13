//+------------------------------------------------------------------+
//|                                          Goldy_Screenshot.mq4    |
//|                                          GOLDY Screenshot V 1.0  |
//|                                          Copyright 2026, Alex    |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Alex"
#property version   "1.00"
#property description "GOLDY Screenshot V 1.0"
#property description "Macht Chart-Screenshots auf Anfrage vom GOLDY TRADER"
#property strict

//+------------------------------------------------------------------+
//| EINGABE-PARAMETER                                                |
//+------------------------------------------------------------------+
input string   Inst_Bezeichnung       = "Wave Chart";        // Bezeichnung (fuer Uebersicht)
input int      Screenshot_Breite      = 1920;                // Screenshot Breite (Pixel)
input int      Screenshot_Hoehe       = 1080;                // Screenshot Hoehe (Pixel)
input int      Pruef_Intervall_Ms     = 1000;                // Pruef-Intervall (Millisekunden)
input string   Request_Datei          = "Goldy_Shared\\screenshot_request.txt";   // Request-Datei Pfad
input string   Screenshot_Datei       = "Goldy_Shared\\chart_screenshot.png";     // Screenshot-Datei Pfad

//+------------------------------------------------------------------+
//| Globale Variablen                                                |
//+------------------------------------------------------------------+
datetime g_letzter_screenshot = 0;
int      g_screenshots_heute = 0;

//+------------------------------------------------------------------+
//| OnInit                                                            |
//+------------------------------------------------------------------+
int OnInit()
{
   EventSetMillisecondTimer(Pruef_Intervall_Ms);
   
   Print("====================================");
   Print("GOLDY Screenshot V 1.0 gestartet");
   Print("Bezeichnung: ", Inst_Bezeichnung);
   Print("Breite: ", Screenshot_Breite, " | Hoehe: ", Screenshot_Hoehe);
   Print("Pruef-Intervall: ", Pruef_Intervall_Ms, " ms");
   Print("Request-Datei: ", Request_Datei);
   Print("Screenshot-Datei: ", Screenshot_Datei);
   Print("====================================");
   
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| OnDeinit                                                          |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   EventKillTimer();
   Print("GOLDY Screenshot V 1.0 beendet. Screenshots heute: ", g_screenshots_heute);
}

//+------------------------------------------------------------------+
//| OnTimer                                                           |
//+------------------------------------------------------------------+
void OnTimer()
{
   // Pruefen ob eine Anfrage vom GOLDY TRADER da ist
   if(RequestVorhanden())
   {
      // Sofort Screenshot machen
      if(ScreenshotMachen())
      {
         g_screenshots_heute++;
         g_letzter_screenshot = TimeCurrent();
         Print("Screenshot #", g_screenshots_heute, " erstellt auf Anfrage");
      }
      else
      {
         Print("FEHLER: Screenshot konnte nicht erstellt werden!");
      }
      
      // Request-Datei loeschen (Anfrage erledigt)
      RequestLoeschen();
   }
}

//+------------------------------------------------------------------+
//| Prueft ob eine Screenshot-Anfrage vorhanden ist                  |
//+------------------------------------------------------------------+
bool RequestVorhanden()
{
   // Pruefen ob die Request-Datei existiert im Common-Ordner
   if(!FileIsExist(Request_Datei, FILE_COMMON))
      return false;
   
   return true;
}

//+------------------------------------------------------------------+
//| Loescht die Request-Datei                                        |
//+------------------------------------------------------------------+
void RequestLoeschen()
{
   if(FileIsExist(Request_Datei, FILE_COMMON))
   {
      FileDelete(Request_Datei, FILE_COMMON);
   }
}

//+------------------------------------------------------------------+
//| Macht einen Screenshot und speichert ihn                         |
//+------------------------------------------------------------------+
bool ScreenshotMachen()
{
   // Screenshot vom aktuellen Chart machen
   // WindowScreenShot speichert im MQL4\Files Ordner
   // Wir muessen es dann in den Common-Ordner kopieren
   
   string temp_datei = "goldy_temp_screenshot.png";
   
   if(!WindowScreenShot(temp_datei, Screenshot_Breite, Screenshot_Hoehe))
   {
      Print("WindowScreenShot fehlgeschlagen. Error: ", GetLastError());
      return false;
   }
   
   // Datei lesen
   int handle_read = FileOpen(temp_datei, FILE_BIN | FILE_READ);
   if(handle_read == INVALID_HANDLE)
   {
      Print("Temp-Datei nicht lesbar. Error: ", GetLastError());
      return false;
   }
   
   int filesize = (int)FileSize(handle_read);
   if(filesize <= 0)
   {
      FileClose(handle_read);
      Print("Temp-Datei ist leer!");
      return false;
   }
   
   uchar data[];
   ArrayResize(data, filesize);
   FileReadArray(handle_read, data, 0, filesize);
   FileClose(handle_read);
   
   // In Common-Ordner schreiben
   int handle_write = FileOpen(Screenshot_Datei, FILE_BIN | FILE_WRITE | FILE_COMMON);
   if(handle_write == INVALID_HANDLE)
   {
      Print("Common-Datei nicht schreibbar. Error: ", GetLastError());
      return false;
   }
   
   FileWriteArray(handle_write, data, 0, filesize);
   FileClose(handle_write);
   
   // Temp-Datei loeschen
   FileDelete(temp_datei);
   
   return true;
}

//+------------------------------------------------------------------+
//| OnTick - nicht benoetigt aber fuer Chart-Aktivitaet              |
//+------------------------------------------------------------------+
void OnTick()
{
   // Nichts tun - alles laeuft ueber Timer
}
//+------------------------------------------------------------------+
