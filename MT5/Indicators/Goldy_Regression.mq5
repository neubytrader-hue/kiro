//+------------------------------------------------------------------+
//|                                              Goldy_Regression.mq5|
//|                                                                  |
//|   Goldy Regression - Polynomial regression channel for MT5       |
//|   Ported from the MT4 version "regression_mt4_v2_2".             |
//|                                                                  |
//|   v2.00:                                                         |
//|     - Removed all colored fills (lines only now)                 |
//|     - Center hardcoded to Gold dotted, width 2                   |
//|     - All lines width 2                                          |
//|     - Dev3 Upper (Short)  = bright red                           |
//|     - Dev3 Lower (Long)   = bright lime green                    |
//|     - Includes Candle Countdown + configurable Alerts            |
//+------------------------------------------------------------------+
#property copyright "Goldy Regression"
#property version   "2.00"
#property strict
#property indicator_chart_window
#property indicator_buffers 8
#property indicator_plots   7

//--- Plot 0: Center line (HARDCODED Gold, dotted, width 2)
#property indicator_label1  "Center"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrGold
#property indicator_style1  STYLE_DOT
#property indicator_width1  2

//--- Plot 1/2: Dev1 (1.27 sigma) - Aqua
#property indicator_label2  "Dev1 Upper"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrAqua
#property indicator_width2  2

#property indicator_label3  "Dev1 Lower"
#property indicator_type3   DRAW_LINE
#property indicator_color3  clrAqua
#property indicator_width3  2

//--- Plot 3/4: Dev2 (1.618 sigma) - bright Red
#property indicator_label4  "Dev2 Upper"
#property indicator_type4   DRAW_LINE
#property indicator_color4  clrRed
#property indicator_width4  2

#property indicator_label5  "Dev2 Lower"
#property indicator_type5   DRAW_LINE
#property indicator_color5  clrRed
#property indicator_width5  2

//--- Plot 5: Dev3 Upper (2.618 sigma) - bright Red (Short)
#property indicator_label6  "Dev3 Upper"
#property indicator_type6   DRAW_LINE
#property indicator_color6  clrRed
#property indicator_width6  2

//--- Plot 6: Dev3 Lower (2.618 sigma) - bright Lime green (Long)
#property indicator_label7  "Dev3 Lower"
#property indicator_type7   DRAW_LINE
#property indicator_color7  clrLime
#property indicator_width7  2

//+------------------------------------------------------------------+
//| Inputs (regression - based on MT4 regression_mt4_v2_2)           |
//+------------------------------------------------------------------+
input datetime _FixedDate              = D'2024.01.01 00:00';
input int      _Period_                = 200;
input int      _RegressionDegree       = 4;
input double   _K_N_L_Dev              = 1.27;
input double   _K_N_L_Dev2             = 1.618;
input double   _K_N_L_Dev3             = 2.618;
input color    _StdChannelColor        = clrGreen;     // (informational, kept for parity)
input color    _RegressionColor1       = clrAqua;      // Dev1 color (upper + lower)
input color    _RegressionColor2       = clrRed;       // Dev2 color (upper + lower, bright red)
input color    _RegressionColor3       = clrRed;       // Dev3 UPPER color (Short, bright red)
input color    _RegressionColor3Lower  = clrLime;      // Dev3 LOWER color (Long, bright lime green)
input bool     _CenterLine             = true;
input bool     _FutureCenterLine       = true;         // master toggle: extend ALL lines into the future
input bool     _UseFixedDate           = false;
input int      _FutureBars             = 50;

//--- Candle Countdown
input bool     _ShowCountdown          = true;
input color    _CountdownColor         = clrGold;
input int      _CountdownFontSize      = 10;
input int      _CountdownRightShift    = 4;
input string   _CountdownFont          = "Arial";

//--- Alerts (extra feature)
input bool     _AlertEnabled           = true;
input bool     _AlertOnDev2            = true;
input bool     _AlertOnMid             = true;
input bool     _AlertOnDev3            = false;
input bool     _AlertOnUpper           = true;
input bool     _AlertOnLower           = true;
input bool     _AlertPopup             = true;
input bool     _AlertPrintLog          = true;
input bool     _AlertGlobalVar         = true;
input int      _AlertTriggerMode       = 1;            // 0 = on tick, 1 = on bar close

//+------------------------------------------------------------------+
//| Buffers                                                          |
//+------------------------------------------------------------------+
double Center[];
double Dev1U[],  Dev1L[];
double Dev2U[],  Dev2L[];
double Dev3U[],  Dev3L[];

//--- hidden buffer for EA access via iCustom() at index 7
//    Values: 0 = no signal,
//            1 = Dev2 upper, 2 = Mid upper, 3 = Dev3 upper,
//           -1 = Dev2 lower,-2 = Mid lower,-3 = Dev3 lower
double SignalBuffer[];

const string OBJ_PREFIX     = "GOLDY_REG_FUTURE_";
const string COUNTDOWN_OBJ  = "GOLDY_CANDLE_COUNTDOWN";

bool     g_armedDev2U     = true;
bool     g_armedMidU      = true;
bool     g_armedDev3U     = true;
bool     g_armedDev2L     = true;
bool     g_armedMidL      = true;
bool     g_armedDev3L     = true;
datetime g_lastCheckedBar = 0;

//+------------------------------------------------------------------+
int OnInit()
{
   SetIndexBuffer(0, Center,       INDICATOR_DATA);
   SetIndexBuffer(1, Dev1U,        INDICATOR_DATA);
   SetIndexBuffer(2, Dev1L,        INDICATOR_DATA);
   SetIndexBuffer(3, Dev2U,        INDICATOR_DATA);
   SetIndexBuffer(4, Dev2L,        INDICATOR_DATA);
   SetIndexBuffer(5, Dev3U,        INDICATOR_DATA);
   SetIndexBuffer(6, Dev3L,        INDICATOR_DATA);
   SetIndexBuffer(7, SignalBuffer, INDICATOR_CALCULATIONS);

   //--- Center line color is HARDCODED to Gold (no input parameter)
   //    Other lines pull color from input parameters
   PlotIndexSetInteger(1, PLOT_LINE_COLOR, _RegressionColor1);       // Dev1 Upper
   PlotIndexSetInteger(2, PLOT_LINE_COLOR, _RegressionColor1);       // Dev1 Lower
   PlotIndexSetInteger(3, PLOT_LINE_COLOR, _RegressionColor2);       // Dev2 Upper
   PlotIndexSetInteger(4, PLOT_LINE_COLOR, _RegressionColor2);       // Dev2 Lower
   PlotIndexSetInteger(5, PLOT_LINE_COLOR, _RegressionColor3);       // Dev3 Upper (Short = red)
   PlotIndexSetInteger(6, PLOT_LINE_COLOR, _RegressionColor3Lower);  // Dev3 Lower (Long  = lime)

   if(!_CenterLine)
      PlotIndexSetInteger(0, PLOT_DRAW_TYPE, DRAW_NONE);

   for(int p = 0; p < 7; p++)
      PlotIndexSetDouble(p, PLOT_EMPTY_VALUE, EMPTY_VALUE);

   IndicatorSetString(INDICATOR_SHORTNAME,
      StringFormat("Goldy Regression (P=%d, deg=%d)", _Period_, _RegressionDegree));

   if(_ShowCountdown)
      EventSetTimer(1);

   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   EventKillTimer();
   DeleteFutureObjects();
   ObjectDelete(0, COUNTDOWN_OBJ);
   if(reason == REASON_REMOVE || reason == REASON_CHARTCLOSE || reason == REASON_RECOMPILE)
      Comment("");
}

//+------------------------------------------------------------------+
void OnTimer()
{
   if(_ShowCountdown)
      UpdateCountdown();
}

//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
{
   int degree = (int)MathMax(1, MathMin(_RegressionDegree, 6));
   int n      = (int)MathMax(degree + 1, _Period_);

   if(rates_total < n + 1)
      return 0;

   int startBar = rates_total - n;

   if(_UseFixedDate)
   {
      int shift = iBarShift(_Symbol, _Period, _FixedDate, false);
      if(shift >= 0 && shift < rates_total)
      {
         startBar = rates_total - 1 - shift;
         if(startBar < 0) startBar = 0;
         n = rates_total - startBar;
      }
   }

   if(n < degree + 1) n = degree + 1;
   if(startBar < 0)   startBar = 0;
   if(startBar + n > rates_total) n = rates_total - startBar;

   //--- reset all line buffers to empty (signal buffer kept across calls)
   for(int i = 0; i < rates_total; i++)
   {
      Center[i] = EMPTY_VALUE;
      Dev1U[i]  = EMPTY_VALUE;  Dev1L[i] = EMPTY_VALUE;
      Dev2U[i]  = EMPTY_VALUE;  Dev2L[i] = EMPTY_VALUE;
      Dev3U[i]  = EMPTY_VALUE;  Dev3L[i] = EMPTY_VALUE;
   }

   if(prev_calculated == 0)
      ArrayInitialize(SignalBuffer, 0.0);

   double coeffs[];
   ArrayResize(coeffs, degree + 1);
   if(!FitPolynomial(close, startBar, n, degree, coeffs))
      return rates_total;

   //--- residuals -> standard deviation
   double sumSq = 0.0;
   for(int i = 0; i < n; i++)
   {
      double xn   = (n > 1) ? (double)i / (double)(n - 1) : 0.0;
      double yfit = EvalPoly(coeffs, degree, xn);
      double e    = close[startBar + i] - yfit;
      sumSq      += e * e;
   }
   double stddev = (n > 0) ? MathSqrt(sumSq / (double)n) : 0.0;

   //--- write line buffers
   for(int i = 0; i < n; i++)
   {
      double xn   = (n > 1) ? (double)i / (double)(n - 1) : 0.0;
      double yfit = EvalPoly(coeffs, degree, xn);
      int    bar  = startBar + i;

      Center[bar] = yfit;
      Dev1U[bar]  = yfit + _K_N_L_Dev  * stddev;
      Dev1L[bar]  = yfit - _K_N_L_Dev  * stddev;
      Dev2U[bar]  = yfit + _K_N_L_Dev2 * stddev;
      Dev2L[bar]  = yfit - _K_N_L_Dev2 * stddev;
      Dev3U[bar]  = yfit + _K_N_L_Dev3 * stddev;
      Dev3L[bar]  = yfit - _K_N_L_Dev3 * stddev;
   }

   //--- extend all 7 lines into the future
   DeleteFutureObjects();
   if(_FutureCenterLine && _FutureBars > 0)
      DrawFutureBands(coeffs, degree, n, stddev, time, rates_total);

   if(_ShowCountdown)
      UpdateCountdown();

   if(_AlertEnabled)
      ProcessAlerts(rates_total, time, high, low, close);

   return rates_total;
}

//+------------------------------------------------------------------+
void UpdateCountdown()
{
   int periodSec = PeriodSeconds(_Period);
   if(periodSec <= 0) return;

   datetime barOpenTime  = (datetime)SeriesInfoInteger(_Symbol, _Period, SERIES_LASTBAR_DATE);
   datetime barCloseTime = (datetime)((long)barOpenTime + (long)periodSec);
   long     leftSec      = (long)(barCloseTime - TimeCurrent());
   if(leftSec < 1) leftSec = 1;

   bool hasHours = (periodSec > 3600);
   bool hasDays  = (periodSec > 86400);

   string msg = "";
   if(hasDays)
   {
      msg += IntegerToString((int)(leftSec / 86400)) + "d ";
      leftSec %= 86400;
   }

   int hours = (int)(leftSec / 3600);
   int mins  = (int)((leftSec % 3600) / 60);
   int secs  = (int)(leftSec % 60);

   if(hasHours)
      msg += StringFormat("%02d:%02d:%02d", hours, mins, secs);
   else
      msg += StringFormat("%02d:%02d", mins, secs);

   datetime objX   = (datetime)((long)barOpenTime + (long)periodSec * (long)_CountdownRightShift);
   double   openP  = iOpen(_Symbol, _Period, 0);
   double   closeP = iClose(_Symbol, _Period, 0);
   double   objY   = MathMax(openP, closeP);

   string fullMsg = "<-- " + msg;

   if(ObjectFind(0, COUNTDOWN_OBJ) < 0)
   {
      ObjectCreate(0, COUNTDOWN_OBJ, OBJ_TEXT, 0, objX, objY);
      ObjectSetInteger(0, COUNTDOWN_OBJ, OBJPROP_ANCHOR,     ANCHOR_LEFT);
      ObjectSetInteger(0, COUNTDOWN_OBJ, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, COUNTDOWN_OBJ, OBJPROP_HIDDEN,     true);
      ObjectSetInteger(0, COUNTDOWN_OBJ, OBJPROP_BACK,       false);
   }
   else
      ObjectMove(0, COUNTDOWN_OBJ, 0, objX, objY);

   ObjectSetInteger(0, COUNTDOWN_OBJ, OBJPROP_COLOR,    _CountdownColor);
   ObjectSetInteger(0, COUNTDOWN_OBJ, OBJPROP_FONTSIZE, _CountdownFontSize);
   ObjectSetString (0, COUNTDOWN_OBJ, OBJPROP_FONT,     _CountdownFont);
   ObjectSetString (0, COUNTDOWN_OBJ, OBJPROP_TEXT,     fullMsg);

   Comment(msg + " left to bar end");
}

//+------------------------------------------------------------------+
//| Alerts - Dev2 / Mid / Dev3 - Variante E (1x per approach)        |
//+------------------------------------------------------------------+
void ProcessAlerts(const int rates_total, const datetime &time[],
                   const double &high[], const double &low[],
                   const double &close[])
{
   if(rates_total < 3) return;

   double upperPrice, lowerPrice;
   datetime checkTime;
   int barIdx;

   if(_AlertTriggerMode == 0)
   {
      barIdx     = rates_total - 1;
      double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      upperPrice = bid;
      lowerPrice = bid;
      checkTime  = TimeCurrent();
   }
   else
   {
      barIdx                = rates_total - 2;
      datetime closedBarTime = time[barIdx];
      if(closedBarTime == g_lastCheckedBar) return;
      g_lastCheckedBar      = closedBarTime;
      upperPrice            = high[barIdx];
      lowerPrice            = low[barIdx];
      checkTime             = closedBarTime;
   }

   double dev2u = Dev2U[barIdx];
   double dev3u = Dev3U[barIdx];
   double dev2l = Dev2L[barIdx];
   double dev3l = Dev3L[barIdx];

   double midU = (dev2u != EMPTY_VALUE && dev3u != EMPTY_VALUE)
                 ? (dev2u + dev3u) / 2.0 : EMPTY_VALUE;
   double midL = (dev2l != EMPTY_VALUE && dev3l != EMPTY_VALUE)
                 ? (dev2l + dev3l) / 2.0 : EMPTY_VALUE;

   if(_AlertOnUpper)
   {
      if(_AlertOnDev2 && dev2u != EMPTY_VALUE)
      {
         if(g_armedDev2U && upperPrice >= dev2u)
         {
            FireAlert("Dev2 Upper", dev2u, upperPrice, checkTime, 1, barIdx);
            g_armedDev2U = false;
         }
         else if(!g_armedDev2U && upperPrice < dev2u)
            g_armedDev2U = true;
      }
      if(_AlertOnMid && midU != EMPTY_VALUE)
      {
         if(g_armedMidU && upperPrice >= midU)
         {
            FireAlert("Mid Upper", midU, upperPrice, checkTime, 2, barIdx);
            g_armedMidU = false;
         }
         else if(!g_armedMidU && upperPrice < midU)
            g_armedMidU = true;
      }
      if(_AlertOnDev3 && dev3u != EMPTY_VALUE)
      {
         if(g_armedDev3U && upperPrice >= dev3u)
         {
            FireAlert("Dev3 Upper", dev3u, upperPrice, checkTime, 3, barIdx);
            g_armedDev3U = false;
         }
         else if(!g_armedDev3U && upperPrice < dev3u)
            g_armedDev3U = true;
      }
   }

   if(_AlertOnLower)
   {
      if(_AlertOnDev2 && dev2l != EMPTY_VALUE)
      {
         if(g_armedDev2L && lowerPrice <= dev2l)
         {
            FireAlert("Dev2 Lower", dev2l, lowerPrice, checkTime, -1, barIdx);
            g_armedDev2L = false;
         }
         else if(!g_armedDev2L && lowerPrice > dev2l)
            g_armedDev2L = true;
      }
      if(_AlertOnMid && midL != EMPTY_VALUE)
      {
         if(g_armedMidL && lowerPrice <= midL)
         {
            FireAlert("Mid Lower", midL, lowerPrice, checkTime, -2, barIdx);
            g_armedMidL = false;
         }
         else if(!g_armedMidL && lowerPrice > midL)
            g_armedMidL = true;
      }
      if(_AlertOnDev3 && dev3l != EMPTY_VALUE)
      {
         if(g_armedDev3L && lowerPrice <= dev3l)
         {
            FireAlert("Dev3 Lower", dev3l, lowerPrice, checkTime, -3, barIdx);
            g_armedDev3L = false;
         }
         else if(!g_armedDev3L && lowerPrice > dev3l)
            g_armedDev3L = true;
      }
   }
}

//+------------------------------------------------------------------+
void FireAlert(string bandName, double bandValue, double price,
               datetime t, int signalCode, int barIdx)
{
   string symbol  = _Symbol;
   string period  = StringSubstr(EnumToString(_Period), 7);
   int    digits  = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   string priceS  = DoubleToString(price,     digits);
   string bandS   = DoubleToString(bandValue, digits);
   string dirWord = (signalCode > 0) ? "ueber" : "unter";

   string text = StringFormat("%s %s: Preis %s %s bei %s",
                              symbol, period, dirWord, bandName, priceS);
   if(_AlertPopup)
      Alert(text);

   if(_AlertPrintLog)
   {
      Print(StringFormat("GOLDY_SIGNAL|%s|%s|%s|%d|%s|%s|%s",
            symbol, period, bandName, signalCode,
            priceS, bandS,
            TimeToString(t, TIME_DATE | TIME_SECONDS)));
   }

   if(_AlertGlobalVar)
   {
      string prefix = "Goldy_" + symbol + "_" + period + "_";
      GlobalVariableSet(prefix + "LastSignal",      (double)signalCode);
      GlobalVariableSet(prefix + "LastSignalTime",  (double)t);
      GlobalVariableSet(prefix + "LastSignalPrice", price);
      GlobalVariableSet(prefix + "LastBandValue",   bandValue);
   }

   if(barIdx >= 0 && barIdx < ArraySize(SignalBuffer))
      SignalBuffer[barIdx] = (double)signalCode;
}

//+------------------------------------------------------------------+
bool FitPolynomial(const double &y[], int startBar, int n, int degree, double &coeffs[])
{
   int m = degree + 1;

   double sumX[];   ArrayResize(sumX,  2 * degree + 1);
   double sumXY[];  ArrayResize(sumXY, m);
   for(int k = 0; k <= 2 * degree; k++) sumX[k]  = 0.0;
   for(int k = 0; k < m; k++)            sumXY[k] = 0.0;

   for(int i = 0; i < n; i++)
   {
      double xn = (n > 1) ? (double)i / (double)(n - 1) : 0.0;
      double yi = y[startBar + i];
      double xpow = 1.0;
      for(int k = 0; k <= 2 * degree; k++)
      {
         sumX[k] += xpow;
         if(k < m) sumXY[k] += xpow * yi;
         xpow *= xn;
      }
   }

   double A[7][7];
   double b[7];
   for(int i = 0; i < m; i++)
   {
      for(int j = 0; j < m; j++)
         A[i][j] = sumX[i + j];
      b[i] = sumXY[i];
   }

   return GaussSolve(A, b, coeffs, m);
}

//+------------------------------------------------------------------+
bool GaussSolve(double &A[][7], double &b[], double &x[], int n)
{
   for(int i = 0; i < n; i++)
   {
      int maxRow = i;
      for(int k = i + 1; k < n; k++)
         if(MathAbs(A[k][i]) > MathAbs(A[maxRow][i]))
            maxRow = k;

      if(maxRow != i)
      {
         for(int k = 0; k < n; k++)
         {
            double t = A[i][k]; A[i][k] = A[maxRow][k]; A[maxRow][k] = t;
         }
         double tb = b[i]; b[i] = b[maxRow]; b[maxRow] = tb;
      }

      if(MathAbs(A[i][i]) < 1e-14)
         return false;

      for(int k = i + 1; k < n; k++)
      {
         double factor = A[k][i] / A[i][i];
         for(int j = i; j < n; j++)
            A[k][j] -= factor * A[i][j];
         b[k] -= factor * b[i];
      }
   }

   for(int i = n - 1; i >= 0; i--)
   {
      x[i] = b[i];
      for(int j = i + 1; j < n; j++)
         x[i] -= A[i][j] * x[j];
      x[i] /= A[i][i];
   }
   return true;
}

//+------------------------------------------------------------------+
double EvalPoly(const double &coeffs[], int degree, double x)
{
   double res = 0.0;
   double xpow = 1.0;
   for(int i = 0; i <= degree; i++)
   {
      res  += coeffs[i] * xpow;
      xpow *= x;
   }
   return res;
}

//+------------------------------------------------------------------+
//| Draw center + all 6 deviation bands into the future via OBJ_TREND|
//+------------------------------------------------------------------+
void DrawFutureBands(const double &coeffs[], int degree, int n, double stddev,
                     const datetime &time[], int rates_total)
{
   int barSeconds = PeriodSeconds(_Period);
   if(barSeconds <= 0) return;

   datetime t0 = time[rates_total - 1];

   double pc = EvalPoly(coeffs, degree, 1.0);
   double prev[7];
   prev[0] = pc;                          // Center
   prev[1] = pc + _K_N_L_Dev  * stddev;   // Dev1U
   prev[2] = pc - _K_N_L_Dev  * stddev;   // Dev1L
   prev[3] = pc + _K_N_L_Dev2 * stddev;   // Dev2U
   prev[4] = pc - _K_N_L_Dev2 * stddev;   // Dev2L
   prev[5] = pc + _K_N_L_Dev3 * stddev;   // Dev3U
   prev[6] = pc - _K_N_L_Dev3 * stddev;   // Dev3L
   datetime prevT = t0;

   //--- styling per line (matches indicator buffer styling)
   string labels[];   ArrayResize(labels, 7);
   color  colors[];   ArrayResize(colors, 7);
   int    styles[];   ArrayResize(styles, 7);

   labels[0]="CENTER"; colors[0]=clrGold;                 styles[0]=STYLE_DOT;
   labels[1]="D1U";    colors[1]=_RegressionColor1;       styles[1]=STYLE_SOLID;
   labels[2]="D1L";    colors[2]=_RegressionColor1;       styles[2]=STYLE_SOLID;
   labels[3]="D2U";    colors[3]=_RegressionColor2;       styles[3]=STYLE_SOLID;
   labels[4]="D2L";    colors[4]=_RegressionColor2;       styles[4]=STYLE_SOLID;
   labels[5]="D3U";    colors[5]=_RegressionColor3;       styles[5]=STYLE_SOLID;
   labels[6]="D3L";    colors[6]=_RegressionColor3Lower;  styles[6]=STYLE_SOLID;

   for(int k = 1; k <= _FutureBars; k++)
   {
      double xn   = 1.0 + (double)k / (double)((n > 1) ? (n - 1) : 1);
      double y    = EvalPoly(coeffs, degree, xn);
      datetime tv = (datetime)(t0 + (long)barSeconds * (long)k);

      double curr[7];
      curr[0] = y;
      curr[1] = y + _K_N_L_Dev  * stddev;
      curr[2] = y - _K_N_L_Dev  * stddev;
      curr[3] = y + _K_N_L_Dev2 * stddev;
      curr[4] = y - _K_N_L_Dev2 * stddev;
      curr[5] = y + _K_N_L_Dev3 * stddev;
      curr[6] = y - _K_N_L_Dev3 * stddev;

      int sStart = _CenterLine ? 0 : 1;
      for(int s = sStart; s < 7; s++)
         DrawFutureSegment(labels[s] + "_" + IntegerToString(k),
                           prevT, prev[s], tv, curr[s],
                           colors[s], (ENUM_LINE_STYLE)styles[s]);

      prevT = tv;
      for(int s = 0; s < 7; s++) prev[s] = curr[s];
   }
}

//+------------------------------------------------------------------+
void DrawFutureSegment(string suffix, datetime t1, double p1,
                       datetime t2, double p2,
                       color c, ENUM_LINE_STYLE style)
{
   string name = OBJ_PREFIX + suffix;
   if(ObjectFind(0, name) < 0)
      ObjectCreate(0, name, OBJ_TREND, 0, t1, p1, t2, p2);
   else
   {
      ObjectMove(0, name, 0, t1, p1);
      ObjectMove(0, name, 1, t2, p2);
   }
   ObjectSetInteger(0, name, OBJPROP_COLOR,      c);
   ObjectSetInteger(0, name, OBJPROP_STYLE,      style);
   ObjectSetInteger(0, name, OBJPROP_WIDTH,      2);          // match indicator width 2
   ObjectSetInteger(0, name, OBJPROP_RAY_LEFT,   false);
   ObjectSetInteger(0, name, OBJPROP_RAY_RIGHT,  false);
   ObjectSetInteger(0, name, OBJPROP_BACK,       false);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN,     true);
}

//+------------------------------------------------------------------+
void DeleteFutureObjects()
{
   int total = ObjectsTotal(0, 0, OBJ_TREND);
   for(int i = total - 1; i >= 0; i--)
   {
      string name = ObjectName(0, i, 0, OBJ_TREND);
      if(StringFind(name, OBJ_PREFIX) == 0)
         ObjectDelete(0, name);
   }
}
//+------------------------------------------------------------------+
