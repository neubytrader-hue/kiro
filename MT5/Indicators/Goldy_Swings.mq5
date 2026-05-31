//+------------------------------------------------------------------+
//|                                                  Goldy_Swings.mq5|
//|                                                                  |
//|   Goldy Swings - Fractal-based swing markers + S/R lines (MT5)   |
//|   Companion indicator for Goldy_Regression.                      |
//|                                                                  |
//|   - Detects swing highs/lows (Bill Williams fractals)            |
//|   - Draws colored circle markers at each swing point             |
//|   - Draws horizontal lines extending into the future             |
//|   - Optional auto-cleanup of lines when price sweeps them        |
//+------------------------------------------------------------------+
#property copyright "Goldy Swings"
#property version   "1.00"
#property strict
#property indicator_chart_window
#property indicator_buffers 0
#property indicator_plots   0

//+------------------------------------------------------------------+
//| Inputs                                                           |
//+------------------------------------------------------------------+
input int             _FractalSize       = 2;            // bars on each side (2 = standard 5-bar fractal)
input color           _SwingHighColor    = clrRed;       // marker color for swing highs
input color           _SwingLowColor     = clrLimeGreen; // marker color for swing lows
input int             _MarkerCode        = 159;          // 159 = circle with dot, 174 = filled circle
input int             _MarkerSize        = 2;            // marker size (1..5)
input bool            _DrawLines         = true;         // draw horizontal lines from swing points
input color           _LineHighColor     = clrRed;       // line color for swing highs
input color           _LineLowColor      = clrLimeGreen; // line color for swing lows
input ENUM_LINE_STYLE _LineStyle         = STYLE_DOT;    // line style
input int             _LineWidth         = 1;            // line width
input bool            _AutoCleanLines    = true;         // delete a line when price sweeps it
input bool            _AlertOnSwing      = false;        // popup when a new fractal forms
input bool            _AlertOnLineSweep  = false;        // popup when a line gets broken
input bool            _PrintLogOnEvents  = true;         // structured Print() to Experts log

const string SWING_PREFIX = "GS_SWING_";
const string LINE_PREFIX  = "GS_LINE_";

//+------------------------------------------------------------------+
int OnInit()
{
   IndicatorSetString(INDICATOR_SHORTNAME,
      StringFormat("Goldy Swings (size=%d)", _FractalSize));
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   if(reason == REASON_REMOVE || reason == REASON_CHARTCLOSE || reason == REASON_RECOMPILE)
      DeleteAllObjects();
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
   int fs = (int)MathMax(2, _FractalSize);

   if(rates_total < fs * 2 + 2)
      return 0;

   //--- where to start scanning for new fractals
   int start = (prev_calculated > 0) ? MathMax(prev_calculated - fs - 2, fs) : fs;

   //--- detect fractals on bars that have 'fs' future bars confirmed
   for(int i = start; i < rates_total - fs; i++)
   {
      if(IsFractalHigh(high, i, fs))
         CreateSwingMarker(SWING_PREFIX + "H_" + IntegerToString((long)time[i]),
                          time[i], high[i], _SwingHighColor, true);

      if(IsFractalLow(low, i, fs))
         CreateSwingMarker(SWING_PREFIX + "L_" + IntegerToString((long)time[i]),
                          time[i], low[i], _SwingLowColor, false);
   }

   //--- sweep / auto-cleanup
   if(_AutoCleanLines && rates_total > 0)
      CleanBrokenLines(high[rates_total-1], low[rates_total-1]);

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
//| Create a circle marker + optional horizontal line                |
//+------------------------------------------------------------------+
void CreateSwingMarker(string name, datetime t, double price, color c, bool isHigh)
{
   //--- skip if already exists
   if(ObjectFind(0, name) >= 0) return;

   //--- circle marker on the candle's high/low
   ObjectCreate    (0, name, OBJ_ARROW, 0, t, price);
   ObjectSetInteger(0, name, OBJPROP_ARROWCODE,  _MarkerCode);
   ObjectSetInteger(0, name, OBJPROP_COLOR,      c);
   ObjectSetInteger(0, name, OBJPROP_WIDTH,      _MarkerSize);
   ObjectSetInteger(0, name, OBJPROP_ANCHOR,     isHigh ? ANCHOR_BOTTOM : ANCHOR_TOP);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN,     true);
   ObjectSetInteger(0, name, OBJPROP_BACK,       false);

   //--- horizontal line extending to the right (auto-extend via RAY_RIGHT)
   if(_DrawLines)
   {
      string lineName = LINE_PREFIX + (isHigh ? "H_" : "L_") + IntegerToString((long)t);
      datetime endT = (datetime)((long)t + (long)PeriodSeconds(_Period));
      if(ObjectFind(0, lineName) < 0)
      {
         ObjectCreate    (0, lineName, OBJ_TREND, 0, t, price, endT, price);
         ObjectSetInteger(0, lineName, OBJPROP_COLOR,      isHigh ? _LineHighColor : _LineLowColor);
         ObjectSetInteger(0, lineName, OBJPROP_STYLE,      _LineStyle);
         ObjectSetInteger(0, lineName, OBJPROP_WIDTH,      _LineWidth);
         ObjectSetInteger(0, lineName, OBJPROP_RAY_LEFT,   false);
         ObjectSetInteger(0, lineName, OBJPROP_RAY_RIGHT,  true);
         ObjectSetInteger(0, lineName, OBJPROP_BACK,       true);
         ObjectSetInteger(0, lineName, OBJPROP_SELECTABLE, false);
         ObjectSetInteger(0, lineName, OBJPROP_HIDDEN,     true);
      }
   }

   //--- alerts / log
   string label   = isHigh ? "Swing High" : "Swing Low";
   int    digits  = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   string priceS  = DoubleToString(price, digits);
   string period  = StringSubstr(EnumToString(_Period), 7);

   if(_AlertOnSwing)
      Alert(StringFormat("%s %s: %s at %s", _Symbol, period, label, priceS));

   if(_PrintLogOnEvents)
      Print(StringFormat("GOLDY_SWING|%s|%s|%s|%s|%s",
            _Symbol, period, isHigh ? "HIGH" : "LOW",
            priceS, TimeToString(t, TIME_DATE | TIME_SECONDS)));
}

//+------------------------------------------------------------------+
//| Delete swing-lines that have been swept by current price         |
//+------------------------------------------------------------------+
void CleanBrokenLines(double currentHigh, double currentLow)
{
   int total = ObjectsTotal(0, 0, OBJ_TREND);
   for(int i = total - 1; i >= 0; i--)
   {
      string name = ObjectName(0, i, 0, OBJ_TREND);
      if(StringFind(name, LINE_PREFIX) != 0) continue;

      double linePrice = ObjectGetDouble(0, name, OBJPROP_PRICE, 0);
      bool   isHigh    = (StringFind(name, LINE_PREFIX + "H_") == 0);

      bool broken = isHigh ? (currentHigh > linePrice)
                           : (currentLow  < linePrice);
      if(broken)
      {
         int    digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
         string priceS = DoubleToString(linePrice, digits);
         string period = StringSubstr(EnumToString(_Period), 7);

         if(_AlertOnLineSweep)
            Alert(StringFormat("%s %s: %s line swept at %s",
                  _Symbol, period, isHigh ? "High" : "Low", priceS));

         if(_PrintLogOnEvents)
            Print(StringFormat("GOLDY_SWING_SWEEP|%s|%s|%s|%s",
                  _Symbol, period, isHigh ? "HIGH" : "LOW", priceS));

         ObjectDelete(0, name);
      }
   }
}

//+------------------------------------------------------------------+
void DeleteAllObjects()
{
   int total = ObjectsTotal(0, 0, OBJ_ARROW);
   for(int i = total - 1; i >= 0; i--)
   {
      string name = ObjectName(0, i, 0, OBJ_ARROW);
      if(StringFind(name, SWING_PREFIX) == 0)
         ObjectDelete(0, name);
   }
   total = ObjectsTotal(0, 0, OBJ_TREND);
   for(int i = total - 1; i >= 0; i--)
   {
      string name = ObjectName(0, i, 0, OBJ_TREND);
      if(StringFind(name, LINE_PREFIX) == 0)
         ObjectDelete(0, name);
   }
}
//+------------------------------------------------------------------+
