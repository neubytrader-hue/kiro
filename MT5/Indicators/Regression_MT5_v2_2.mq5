//+------------------------------------------------------------------+
//|                                          Regression_MT5_v2_2.mq5 |
//|                                                                  |
//|   Polynomial regression channel for MetaTrader 5                 |
//|   Ported from the MT4 version "regression_mt4_v2_2".             |
//|                                                                  |
//|   - Polynomial regression of configurable degree (default 4)     |
//|   - Three Fibonacci-based standard-deviation channels            |
//|   - Filled areas between the channels                            |
//|   - Optional center line (with optional future projection)       |
//|   - Optional fixed start date for the regression window          |
//+------------------------------------------------------------------+
#property copyright "Ported from MT4 regression_mt4_v2_2"
#property version   "2.20"
#property strict
#property indicator_chart_window
#property indicator_buffers 15
#property indicator_plots   11

//--- Plot 0: Center line ------------------------------------------
#property indicator_label1  "Center"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrAqua
#property indicator_style1  STYLE_DOT
#property indicator_width1  1

//--- Plot 1/2: Dev1 (1.27 sigma) ---------------------------------
#property indicator_label2  "Dev1 Upper"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrAqua
#property indicator_width2  1

#property indicator_label3  "Dev1 Lower"
#property indicator_type3   DRAW_LINE
#property indicator_color3  clrAqua
#property indicator_width3  1

//--- Plot 3/4: Dev2 (1.618 sigma) --------------------------------
#property indicator_label4  "Dev2 Upper"
#property indicator_type4   DRAW_LINE
#property indicator_color4  clrRed
#property indicator_width4  1

#property indicator_label5  "Dev2 Lower"
#property indicator_type5   DRAW_LINE
#property indicator_color5  clrRed
#property indicator_width5  1

//--- Plot 5/6: Dev3 (2.618 sigma) --------------------------------
#property indicator_label6  "Dev3 Upper"
#property indicator_type6   DRAW_LINE
#property indicator_color6  clrFireBrick
#property indicator_width6  1

#property indicator_label7  "Dev3 Lower"
#property indicator_type7   DRAW_LINE
#property indicator_color7  clrFireBrick
#property indicator_width7  1

//--- Plot 7: Fill between Dev1U and Dev2U ------------------------
#property indicator_label8  "Fill Upper Inner"
#property indicator_type8   DRAW_FILLING
#property indicator_color8  C'0,0,48'

//--- Plot 8: Fill between Dev2U and Dev3U ------------------------
#property indicator_label9  "Fill Upper Outer"
#property indicator_type9   DRAW_FILLING
#property indicator_color9  C'48,0,0'

//--- Plot 9: Fill between Dev1L and Dev2L ------------------------
#property indicator_label10 "Fill Lower Inner"
#property indicator_type10  DRAW_FILLING
#property indicator_color10 C'0,0,48'

//--- Plot 10: Fill between Dev2L and Dev3L -----------------------
#property indicator_label11 "Fill Lower Outer"
#property indicator_type11  DRAW_FILLING
#property indicator_color11 C'48,0,0'

//+------------------------------------------------------------------+
//| Inputs                                                           |
//+------------------------------------------------------------------+
input datetime _FixedDate         = D'2024.01.01 00:00';   // start date if _UseFixedDate=true
input int      _Period_           = 200;                   // number of bars in the window
input int      _RegressionDegree  = 4;                     // polynomial degree (1..6)
input double   _K_N_L_Dev         = 1.27;                  // sigma multiplier #1
input double   _K_N_L_Dev2        = 1.618;                 // sigma multiplier #2
input double   _K_N_L_Dev3        = 2.618;                 // sigma multiplier #3
input color    _StdChannelColor   = clrGreen;              // (informational, kept for parity)
input color    _RegressionColor1  = clrAqua;               // Dev1 + Center color
input color    _RegressionColor2  = clrRed;                // Dev2 color
input color    _RegressionColor3  = C'160,0,0';            // Dev3 color
input color    _FillColor1        = C'0,0,48';             // fill between Dev1 and Dev2
input color    _FillColor2        = C'48,0,0';             // fill between Dev2 and Dev3
input bool     _CenterLine        = true;                  // draw center line
input bool     _FutureCenterLine  = true;                  // extend center line into future
input bool     _UseFixedDate      = false;                 // start regression from _FixedDate
input int      _FutureBars        = 50;                    // bars to project into the future

//+------------------------------------------------------------------+
//| Buffers                                                          |
//+------------------------------------------------------------------+
double Center[];
double Dev1U[],  Dev1L[];
double Dev2U[],  Dev2L[];
double Dev3U[],  Dev3L[];
double FillUI_A[], FillUI_B[];   // fill upper inner  (Dev1U .. Dev2U)
double FillUO_A[], FillUO_B[];   // fill upper outer  (Dev2U .. Dev3U)
double FillLI_A[], FillLI_B[];   // fill lower inner  (Dev1L .. Dev2L)
double FillLO_A[], FillLO_B[];   // fill lower outer  (Dev2L .. Dev3L)

const string OBJ_PREFIX = "REG_FUTURE_";

//+------------------------------------------------------------------+
//| Initialization                                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   //--- bind buffers
   SetIndexBuffer(0,  Center,    INDICATOR_DATA);
   SetIndexBuffer(1,  Dev1U,     INDICATOR_DATA);
   SetIndexBuffer(2,  Dev1L,     INDICATOR_DATA);
   SetIndexBuffer(3,  Dev2U,     INDICATOR_DATA);
   SetIndexBuffer(4,  Dev2L,     INDICATOR_DATA);
   SetIndexBuffer(5,  Dev3U,     INDICATOR_DATA);
   SetIndexBuffer(6,  Dev3L,     INDICATOR_DATA);
   SetIndexBuffer(7,  FillUI_A,  INDICATOR_DATA);
   SetIndexBuffer(8,  FillUI_B,  INDICATOR_DATA);
   SetIndexBuffer(9,  FillUO_A,  INDICATOR_DATA);
   SetIndexBuffer(10, FillUO_B,  INDICATOR_DATA);
   SetIndexBuffer(11, FillLI_A,  INDICATOR_DATA);
   SetIndexBuffer(12, FillLI_B,  INDICATOR_DATA);
   SetIndexBuffer(13, FillLO_A,  INDICATOR_DATA);
   SetIndexBuffer(14, FillLO_B,  INDICATOR_DATA);

   //--- apply colors from inputs (overrides #property defaults)
   PlotIndexSetInteger(0, PLOT_LINE_COLOR, _RegressionColor1);     // Center
   PlotIndexSetInteger(1, PLOT_LINE_COLOR, _RegressionColor1);     // Dev1U
   PlotIndexSetInteger(2, PLOT_LINE_COLOR, _RegressionColor1);     // Dev1L
   PlotIndexSetInteger(3, PLOT_LINE_COLOR, _RegressionColor2);     // Dev2U
   PlotIndexSetInteger(4, PLOT_LINE_COLOR, _RegressionColor2);     // Dev2L
   PlotIndexSetInteger(5, PLOT_LINE_COLOR, _RegressionColor3);     // Dev3U
   PlotIndexSetInteger(6, PLOT_LINE_COLOR, _RegressionColor3);     // Dev3L

   //--- DRAW_FILLING uses two color slots; set both to the fill color
   PlotIndexSetInteger(7, PLOT_LINE_COLOR, 0, _FillColor1);
   PlotIndexSetInteger(7, PLOT_LINE_COLOR, 1, _FillColor1);
   PlotIndexSetInteger(8, PLOT_LINE_COLOR, 0, _FillColor2);
   PlotIndexSetInteger(8, PLOT_LINE_COLOR, 1, _FillColor2);
   PlotIndexSetInteger(9, PLOT_LINE_COLOR, 0, _FillColor1);
   PlotIndexSetInteger(9, PLOT_LINE_COLOR, 1, _FillColor1);
   PlotIndexSetInteger(10, PLOT_LINE_COLOR, 0, _FillColor2);
   PlotIndexSetInteger(10, PLOT_LINE_COLOR, 1, _FillColor2);

   //--- hide center line if disabled
   if(!_CenterLine)
      PlotIndexSetInteger(0, PLOT_DRAW_TYPE, DRAW_NONE);

   //--- empty value for all plots
   for(int p = 0; p < 11; p++)
      PlotIndexSetDouble(p, PLOT_EMPTY_VALUE, EMPTY_VALUE);

   IndicatorSetString(INDICATOR_SHORTNAME,
      StringFormat("Regression(P=%d, deg=%d)", _Period_, _RegressionDegree));

   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Deinitialization                                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   DeleteFutureObjects();
}

//+------------------------------------------------------------------+
//| Calculation                                                      |
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

   //--- determine the starting bar of the regression window
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

   //--- reset all buffers to empty
   for(int i = 0; i < rates_total; i++)
   {
      Center[i]   = EMPTY_VALUE;
      Dev1U[i]    = EMPTY_VALUE;  Dev1L[i]   = EMPTY_VALUE;
      Dev2U[i]    = EMPTY_VALUE;  Dev2L[i]   = EMPTY_VALUE;
      Dev3U[i]    = EMPTY_VALUE;  Dev3L[i]   = EMPTY_VALUE;
      FillUI_A[i] = EMPTY_VALUE;  FillUI_B[i] = EMPTY_VALUE;
      FillUO_A[i] = EMPTY_VALUE;  FillUO_B[i] = EMPTY_VALUE;
      FillLI_A[i] = EMPTY_VALUE;  FillLI_B[i] = EMPTY_VALUE;
      FillLO_A[i] = EMPTY_VALUE;  FillLO_B[i] = EMPTY_VALUE;
   }

   //--- fit the polynomial via normal equations + Gauss elimination
   double coeffs[];
   ArrayResize(coeffs, degree + 1);
   if(!FitPolynomial(close, startBar, n, degree, coeffs))
      return rates_total;

   //--- compute residuals -> standard deviation
   double sumSq = 0.0;
   for(int i = 0; i < n; i++)
   {
      double xn   = (n > 1) ? (double)i / (double)(n - 1) : 0.0;
      double yfit = EvalPoly(coeffs, degree, xn);
      double yreal = close[startBar + i];
      double e = yreal - yfit;
      sumSq += e * e;
   }
   double stddev = (n > 0) ? MathSqrt(sumSq / (double)n) : 0.0;

   //--- write line buffers and fill helpers
   for(int i = 0; i < n; i++)
   {
      double xn   = (n > 1) ? (double)i / (double)(n - 1) : 0.0;
      double yfit = EvalPoly(coeffs, degree, xn);
      int bar = startBar + i;

      Center[bar] = yfit;
      Dev1U[bar]  = yfit + _K_N_L_Dev  * stddev;
      Dev1L[bar]  = yfit - _K_N_L_Dev  * stddev;
      Dev2U[bar]  = yfit + _K_N_L_Dev2 * stddev;
      Dev2L[bar]  = yfit - _K_N_L_Dev2 * stddev;
      Dev3U[bar]  = yfit + _K_N_L_Dev3 * stddev;
      Dev3L[bar]  = yfit - _K_N_L_Dev3 * stddev;

      FillUI_A[bar] = Dev1U[bar];   FillUI_B[bar] = Dev2U[bar];
      FillUO_A[bar] = Dev2U[bar];   FillUO_B[bar] = Dev3U[bar];
      FillLI_A[bar] = Dev1L[bar];   FillLI_B[bar] = Dev2L[bar];
      FillLO_A[bar] = Dev2L[bar];   FillLO_B[bar] = Dev3L[bar];
   }

   //--- future projection of the center line (chart objects)
   DeleteFutureObjects();
   if(_CenterLine && _FutureCenterLine && _FutureBars > 0)
      DrawFutureCenterLine(coeffs, degree, n, time, rates_total);

   return rates_total;
}

//+------------------------------------------------------------------+
//| Polynomial regression: build normal equations and solve          |
//+------------------------------------------------------------------+
bool FitPolynomial(const double &y[], int startBar, int n, int degree, double &coeffs[])
{
   int m = degree + 1;

   double sumX[];   ArrayResize(sumX, 2 * degree + 1);
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

   //--- assemble m x m matrix A and RHS b
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
//| Gaussian elimination with partial pivoting                       |
//+------------------------------------------------------------------+
bool GaussSolve(double &A[][7], double &b[], double &x[], int n)
{
   for(int i = 0; i < n; i++)
   {
      //--- pivot
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

      //--- eliminate
      for(int k = i + 1; k < n; k++)
      {
         double factor = A[k][i] / A[i][i];
         for(int j = i; j < n; j++)
            A[k][j] -= factor * A[i][j];
         b[k] -= factor * b[i];
      }
   }

   //--- back substitution
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
//| Evaluate polynomial sum_k coeffs[k] * x^k                        |
//+------------------------------------------------------------------+
double EvalPoly(const double &coeffs[], int degree, double x)
{
   double res = 0.0;
   double xpow = 1.0;
   for(int i = 0; i <= degree; i++)
   {
      res += coeffs[i] * xpow;
      xpow *= x;
   }
   return res;
}

//+------------------------------------------------------------------+
//| Draw center-line projection into the future via OBJ_TREND        |
//+------------------------------------------------------------------+
void DrawFutureCenterLine(const double &coeffs[], int degree, int n,
                          const datetime &time[], int rates_total)
{
   int barSeconds = PeriodSeconds(_Period);
   if(barSeconds <= 0) return;

   datetime t0     = time[rates_total - 1];
   double   prevY  = EvalPoly(coeffs, degree, 1.0);
   datetime prevT  = t0;

   for(int k = 1; k <= _FutureBars; k++)
   {
      double   xn   = 1.0 + (double)k / (double)((n > 1) ? (n - 1) : 1);
      double   yval = EvalPoly(coeffs, degree, xn);
      datetime tval = (datetime)(t0 + (long)barSeconds * (long)k);

      string name = OBJ_PREFIX + IntegerToString(k);
      if(ObjectFind(0, name) < 0)
         ObjectCreate(0, name, OBJ_TREND, 0, prevT, prevY, tval, yval);
      else
      {
         ObjectMove(0, name, 0, prevT, prevY);
         ObjectMove(0, name, 1, tval,  yval);
      }
      ObjectSetInteger(0, name, OBJPROP_COLOR,      _RegressionColor1);
      ObjectSetInteger(0, name, OBJPROP_STYLE,      STYLE_DOT);
      ObjectSetInteger(0, name, OBJPROP_WIDTH,      1);
      ObjectSetInteger(0, name, OBJPROP_RAY_LEFT,   false);
      ObjectSetInteger(0, name, OBJPROP_RAY_RIGHT,  false);
      ObjectSetInteger(0, name, OBJPROP_BACK,       false);
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, name, OBJPROP_HIDDEN,     true);

      prevT = tval;
      prevY = yval;
   }
}

//+------------------------------------------------------------------+
//| Remove all future-projection objects created by this indicator   |
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
