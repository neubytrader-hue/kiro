//+------------------------------------------------------------------+
//|                                          GOLDY_Synergy_V1.mq5    |
//|                                                                  |
//|   GOLDY Synergy V 1.0 - Active Support / Resistance for MT5      |
//|                                                                  |
//|   Plots active resistance / support levels using:                |
//|     - Bill Williams fractals (default 5-bar, fs = 2)             |
//|     - EMA(9) of High and Low (1-bar shifted)                     |
//|     - Typical price filter:  (Open+High+Low+Close) / 4           |
//|                                                                  |
//|   Logic per bar i (chronological, oldest -> newest):             |
//|     typ     = (O[i] + H[i] + L[i] + C[i]) / 4                    |
//|     emaH    = EMA(High, 9, shift=1) at bar i                     |
//|     emaL    = EMA(Low,  9, shift=1) at bar i                     |
//|     if (FractalHigh(i)  AND  typ > emaH)  Resistance[i] = H[i]   |
//|     else                                  Resistance[i] = R[i-1] |
//|     if (FractalLow(i)   AND  typ < emaL)  Support[i]    = L[i]   |
//|     else                                  Support[i]    = S[i-1] |
//|                                                                  |
//|   Companion to Goldy_Regression / Goldy_Swings.                  |
//+------------------------------------------------------------------+
#property copyright "GOLDY Synergy"
#property version   "1.00"
#property strict
#property indicator_chart_window
#property indicator_buffers 2
#property indicator_plots   2

//--- Plot 0: Active Resistance (dotted arrow, MediumSeaGreen)
#property indicator_label1  "Active Resistance"
#property indicator_type1   DRAW_ARROW
#property indicator_color1  clrMediumSeaGreen
#property indicator_width1  1

//--- Plot 1: Active Support (dotted arrow, Salmon)
#property indicator_label2  "Active Support"
#property indicator_type2   DRAW_ARROW
#property indicator_color2  clrSalmon
#property indicator_width2  1

//+------------------------------------------------------------------+
//| Inputs                                                           |
//+------------------------------------------------------------------+
input color _ResistanceColor = clrMediumSeaGreen; // Resistance dot color
input color _SupportColor    = clrSalmon;         // Support dot color
input int   _ArrowCode       = 167;               // Wingding code (167 = small dot, like original)
input int   _DotWidth        = 1;                 // Dot size (1..5)
input int   _EmaPeriod       = 9;                 // EMA period for High / Low
input int   _EmaShift        = 1;                 // EMA shift (1 = compare vs previous-bar EMA, like original)
input int   _FractalSize     = 2;                 // Fractal half-size (2 = standard 5-bar fractal)

//--- Alerts (extra feature, off by default to stay close to original)
input bool  _AlertOnNewLevel = false;             // popup when a new S/R level forms
input bool  _PrintLogOnEvent = true;              // structured Print() to Experts log

//+------------------------------------------------------------------+
//| Buffers + handles                                                |
//+------------------------------------------------------------------+
double Resistance[];
double Support[];

double EmaHighBuf[];   // EMA of High, copied from indicator handle
double EmaLowBuf[];    // EMA of Low,  copied from indicator handle

int hEmaHigh = INVALID_HANDLE;
int hEmaLow  = INVALID_HANDLE;

//--- de-dup state for the Alert / Print event
datetime g_lastResistanceTime = 0;
datetime g_lastSupportTime    = 0;
double   g_lastResistance     = 0.0;
double   g_lastSupport        = 0.0;

//+------------------------------------------------------------------+
int OnInit()
{
   SetIndexBuffer(0, Resistance, INDICATOR_DATA);
   SetIndexBuffer(1, Support,    INDICATOR_DATA);

   PlotIndexSetInteger(0, PLOT_LINE_COLOR,  _ResistanceColor);
   PlotIndexSetInteger(1, PLOT_LINE_COLOR,  _SupportColor);
   PlotIndexSetInteger(0, PLOT_ARROW,       _ArrowCode);
   PlotIndexSetInteger(1, PLOT_ARROW,       _ArrowCode);
   PlotIndexSetInteger(0, PLOT_LINE_WIDTH,  _DotWidth);
   PlotIndexSetInteger(1, PLOT_LINE_WIDTH,  _DotWidth);
   PlotIndexSetDouble (0, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetDouble (1, PLOT_EMPTY_VALUE, EMPTY_VALUE);

   IndicatorSetString(INDICATOR_SHORTNAME, "GOLDY Synergy V 1.0");

   //--- create EMA handles (ma_shift = _EmaShift preserves the original
   //    "compare current bar's typical price against the EMA of the
   //    previous bar" behaviour from the MT4 source).
   hEmaHigh = iMA(_Symbol, _Period, _EmaPeriod, _EmaShift, MODE_EMA, PRICE_HIGH);
   hEmaLow  = iMA(_Symbol, _Period, _EmaPeriod, _EmaShift, MODE_EMA, PRICE_LOW);

   if(hEmaHigh == INVALID_HANDLE || hEmaLow == INVALID_HANDLE)
   {
      Print("GOLDY Synergy: Failed to create EMA handles");
      return INIT_FAILED;
   }

   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   if(hEmaHigh != INVALID_HANDLE) IndicatorRelease(hEmaHigh);
   if(hEmaLow  != INVALID_HANDLE) IndicatorRelease(hEmaLow);
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
   int fs        = (int)MathMax(2, _FractalSize);
   int minNeeded = fs * 2 + _EmaPeriod + _EmaShift + 2;
   if(rates_total < minNeeded)
      return 0;

   //--- pull EMA buffers from the iMA handles
   if(CopyBuffer(hEmaHigh, 0, 0, rates_total, EmaHighBuf) <= 0) return prev_calculated;
   if(CopyBuffer(hEmaLow,  0, 0, rates_total, EmaLowBuf)  <= 0) return prev_calculated;

   //--- decide where to start the main loop
   //    First run  -> from the earliest bar that has both a valid EMA
   //                  and 'fs' bars on its left side.
   //    Live tick  -> step back fs+1 bars to allow newly-forming
   //                  fractals to be confirmed retroactively.
   int firstValid = MathMax(fs + 1, _EmaPeriod + _EmaShift + 1);
   int start;
   if(prev_calculated == 0)
   {
      start = firstValid;
      for(int i = 0; i < start; i++)
      {
         Resistance[i] = EMPTY_VALUE;
         Support[i]    = EMPTY_VALUE;
      }
   }
   else
   {
      start = MathMax(prev_calculated - fs - 1, firstValid);
   }

   //--- main loop in chronological order (i = 0 oldest, i = rates_total-1 newest)
   for(int i = start; i < rates_total; i++)
   {
      //--- 1. carry the previous bar's level forward by default
      Resistance[i] = (i > 0 && Resistance[i-1] != EMPTY_VALUE) ? Resistance[i-1] : EMPTY_VALUE;
      Support[i]    = (i > 0 && Support[i-1]    != EMPTY_VALUE) ? Support[i-1]    : EMPTY_VALUE;

      //--- 2. fractals can only be confirmed once 'fs' bars to the right exist
      if(i + fs >= rates_total) continue;
      if(i < fs)                continue;

      double emaH = EmaHighBuf[i];
      double emaL = EmaLowBuf [i];
      if(emaH <= 0.0 || emaL <= 0.0) continue;

      double typ = (open[i] + high[i] + low[i] + close[i]) / 4.0;

      //--- 3. confirmed up-fractal + typical price above EMA(High) -> new resistance
      if(IsFractalHigh(high, i, fs) && typ > emaH)
      {
         Resistance[i] = high[i];
         OnNewLevel(true, time[i], high[i]);
      }

      //--- 4. confirmed down-fractal + typical price below EMA(Low) -> new support
      if(IsFractalLow(low, i, fs) && typ < emaL)
      {
         Support[i] = low[i];
         OnNewLevel(false, time[i], low[i]);
      }
   }

   return rates_total;
}

//+------------------------------------------------------------------+
//| Fractal detection (Bill Williams style)                          |
//+------------------------------------------------------------------+
bool IsFractalHigh(const double &h[], int i, int fs)
{
   double v = h[i];
   for(int k = 1; k <= fs; k++)
      if(v <= h[i-k] || v <= h[i+k])
         return false;
   return true;
}

bool IsFractalLow(const double &l[], int i, int fs)
{
   double v = l[i];
   for(int k = 1; k <= fs; k++)
      if(v >= l[i-k] || v >= l[i+k])
         return false;
   return true;
}

//+------------------------------------------------------------------+
//| Alert / log when a new active S/R level is confirmed             |
//+------------------------------------------------------------------+
void OnNewLevel(bool isResistance, datetime t, double price)
{
   //--- de-dup: only fire once per (side, time, price)
   if(isResistance)
   {
      if(price == g_lastResistance && t == g_lastResistanceTime) return;
      g_lastResistance     = price;
      g_lastResistanceTime = t;
   }
   else
   {
      if(price == g_lastSupport && t == g_lastSupportTime) return;
      g_lastSupport     = price;
      g_lastSupportTime = t;
   }

   int    digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   string priceS = DoubleToString(price, digits);
   string period = StringSubstr(EnumToString(_Period), 7);
   string side   = isResistance ? "Resistance" : "Support";

   if(_AlertOnNewLevel)
      Alert(StringFormat("%s %s: New Active %s at %s",
            _Symbol, period, side, priceS));

   if(_PrintLogOnEvent)
      Print(StringFormat("GOLDY_SYNERGY|%s|%s|%s|%s|%s",
            _Symbol, period, side, priceS,
            TimeToString(t, TIME_DATE | TIME_SECONDS)));
}
//+------------------------------------------------------------------+
