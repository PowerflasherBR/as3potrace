
using System;
using System.Collections.Generic;
using System.Drawing;
using System.Drawing.Imaging;
using System.Collections;

//Copyright (C) 2001-2007 Peter Selinger
//Copyright (C) 2009 Wolfgang Nagl

// This program is free software; you can redistribute it and/or modify  it under the terms of the GNU General Public License as published by  the Free Software Foundation; either version 2 of the License, or (at  your option) any later version.
// This program is distributed in the hope that it will be useful, but  WITHOUT ANY WARRANTY; without even the implied warranty of  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU  General Public License for more details.
// You should have received a copy of the GNU General Public License  along with this program; if not, write to the Free Software  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307,  USA. 

namespace CsPotrace
{
    
    public class Potrace
       
    {
        
        #region additional Class definitions
        //----------------------Potrace Constants and aux functions
        const int POTRACE_CORNER = 1;
        const int POTRACE_CURVETO = 2;
        static double COS179 = Math.Cos(179 * Math.PI / 180);
        /// <summary>
        /// area of largest path to be ignored
        /// </summary>
        public static int turdsize = 2;     
        /// <summary>
        ///  corner threshold
        /// </summary>
        public static double alphamax = 1.0;     
        /// <summary>
        ///  use curve optimization
        ///  optimize the path p, replacing sequences of Bezier segments by a
        ///  single segment when possible.
        /// </summary>
        public static bool curveoptimizing = true;
        /// <summary>
        /// curve optimization tolerance
        /// </summary>
        public static double opttolerance = 0.2;     

        /* ---------------------------------------------------------------------- */
        enum direction
        {
            North,

            East,

            South,

            West,
        }
        /// <summary>
        /// Kind of Curve : Line or Bezier
        /// </summary>
        public enum CurveKind
        {
            Line,
            Bezier
        }
        /// <summary>
        /// Holds the information about der produced curves
        /// </summary>
        public struct Curve
        {
            /// <summary>
            /// Bezier or Line
            /// </summary>
            public CurveKind Kind;
            /// <summary>
            /// Startpoint
            /// </summary>
            public dPoint A;
            /// <summary>
            /// ControlPoint
            /// </summary>
            public dPoint ControlPointA;
            /// <summary>
            /// ControlPoint
            /// </summary>
            public dPoint ControlPointB;
            /// <summary>
            /// Endpoint
            /// </summary>
            public dPoint B;
          /// <summary>
          /// Creates a curve
          /// </summary>
          /// <param name="Kind"></param>
          /// <param name="A">Startpoint</param>
          /// <param name="ControlPointA">Controlpoint</param>
          /// <param name="ControlPointB">Controlpoint</param>
          /// <param name="B">Endpoint</param>
            public Curve(CurveKind Kind, dPoint A, dPoint ControlPointA, dPoint ControlPointB, dPoint B)
            {

                this.Kind = Kind;
                this.A = A;
                this.B = B;
                this.ControlPointA = ControlPointA;
                this.ControlPointB = ControlPointB;
                this.B = B;
            }
        }
        private class Path
        {
            public int area;
            public ArrayList MonotonIntervals;
            public iPoint[] pt;
            public int[] Lon;
            public SumStruct[] Sums;
            public int[] po;
            public privcurve Curves;
            public privcurve OptimizedCurves;
            public privcurve FCurves;


        }
        struct iPoint
        {
            public int x;
            public int y;
            public iPoint(int x, int y)
            {
                this.x = x;
                this.y = y;
            }

        }
        /// <summary>
        /// Holds the coordinates of a Point
        /// </summary>
        public struct dPoint
        {
            /// <summary>
            /// x-coordinate
            /// </summary>
            public double x;
            /// <summary>
            /// y-coordinate
            /// </summary>
            public double y;
            /// <summary>
            /// Creates a point
            /// </summary>
            /// <param name="x">x-coordinate</param>
            /// <param name="y">y-coordinate</param>
            public dPoint(double x, double y)
            {
                this.x = x;
                this.y = y;
            }

        }
        struct SumStruct
        {
            public int x;
            public int y;
            public int xy;
            public int x2;
            public int y2;

        }
        private class privcurve
        {
            public int n;            /* number of segments */
            public int[] tag;         /* tag[n]: POTRACE_CORNER or POTRACE_CURVETO */
            public dPoint[,] ControlPoints;/* c[n][i]: control points. 
		       c[n][0] is unused for tag[n]=POTRACE_CORNER */
            public dPoint[] vertex;      /* for POTRACE_CORNER, this equals c[1] */
            /* (*c)[3]; /* c[n][i]: control points. 
           c[n][0] is unused for tag[n]=POTRACE_CORNER */

            public double[] alpha;    /* only for POTRACE_CURVETO */
            public double[] alpha0;   /* "uncropped" alpha parameter - for debug output only */
            public double[] beta;
            public privcurve(int Count)
            {
                n = Count;
                tag = new int[n];
                ControlPoints = new dPoint[n, 3];
                vertex = new dPoint[n];
                alpha = new double[n];
                alpha0 = new double[n];
                beta = new double[n];

            }

        };

        #region auxiliary functions


        /* calculate point of a bezier curve */
        static dPoint bezier(double t, dPoint p0, dPoint p1, dPoint p2, dPoint p3)
        {
            double s = 1 - t;
            dPoint res;

            /* Note: a good optimizing compiler (such as gcc-3) reduces the
               following to 16 multiplications, using common subexpression
               elimination. */

            res.x = s * s * s * p0.x + 3 * (s * s * t) * p1.x + 3 * (t * t * s) * p2.x + t * t * t * p3.x;
            res.y = s * s * s * p0.y + 3 * (s * s * t) * p1.y + 3 * (t * t * s) * p2.y + t * t * t * p3.y;

            return res;
        }

        /* calculate the point t in [0..1] on the (convex) bezier curve
            (p0,p1,p2,p3) which is tangent to q1-q0. Return -1.0 if there is no
            solution in [0..1]. */
        static double tangent(dPoint p0, dPoint p1, dPoint p2, dPoint p3, dPoint q0, dPoint q1)
        {
            double A, B, C;   /* (1-t)^2 A + 2(1-t)t B + t^2 C = 0 */
            double a, b, c;   /* a t^2 + b t + c = 0 */
            double d, s, r1, r2;

            A = cprod(p0, p1, q0, q1);
            B = cprod(p1, p2, q0, q1);
            C = cprod(p2, p3, q0, q1);

            a = A - 2 * B + C;
            b = -2 * A + 2 * B;
            c = A;

            d = b * b - 4 * a * c;

            if (a == 0 || d < 0)
            {
                return -1.0;
            }

            s = Math.Sqrt(d);

            r1 = (-b + s) / (2 * a);
            r2 = (-b - s) / (2 * a);

            if (r1 >= 0 && r1 <= 1)
            {
                return r1;
            }
            else if (r2 >= 0 && r2 <= 1)
            {
                return r2;
            }
            else
            {
                return -1.0;
            }
        }
        /* calculate distance between two points */
        static double ddist(dPoint p, dPoint q)
        {
            return Math.Sqrt((p.x - q.x) * (p.x - q.x) + (p.y - q.y) * (p.y - q.y));
        }
        /* calculate p1 x p2 */
        static int xprod(iPoint p1, iPoint p2)
        {
            return p1.x * p2.y - p1.y * p2.x;
        }
        /* calculate p1 x p2 */
        static double xprod(dPoint p1, dPoint p2)
        {
            return p1.x * p2.y - p1.y * p2.x;
        }
        /* calculate (p1-p0)x(p3-p2) */
        static double cprod(dPoint p0, dPoint p1, dPoint p2, dPoint p3)
        {
            double x1, y1, x2, y2;

            x1 = p1.x - p0.x;
            y1 = p1.y - p0.y;
            x2 = p3.x - p2.x;
            y2 = p3.y - p2.y;

            return x1 * y2 - x2 * y1;
        }
        /* calculate (p1-p0)*(p2-p0) */
        static double iprod(dPoint p0, dPoint p1, dPoint p2)
        {
            double x1, y1, x2, y2;

            x1 = p1.x - p0.x;
            y1 = p1.y - p0.y;
            x2 = p2.x - p0.x;
            y2 = p2.y - p0.y;

            return x1 * x2 + y1 * y2;
        }

        /* calculate (p1-p0)*(p3-p2) */
        static double iprod1(dPoint p0, dPoint p1, dPoint p2, dPoint p3)
        {
            double x1, y1, x2, y2;

            x1 = p1.x - p0.x;
            y1 = p1.y - p0.y;
            x2 = p3.x - p2.x;
            y2 = p3.y - p2.y;

            return x1 * x2 + y1 * y2;
        }

        /* return a direction that is 90 degrees counterclockwise from p2-p0,
           but then restricted to one of the major wind directions (n, nw, w, etc) */
        static iPoint dorth_infty(dPoint p0, dPoint p2)
        {
            iPoint r;

            r.y = sign(p2.x - p0.x);
            r.x = -sign(p2.y - p0.y);

            return r;
        }
        /* range over the straight line segment [a,b] when lambda ranges over [0,1] */
        static dPoint interval(double lambda, dPoint a, dPoint b)
        {
            dPoint res;

            res.x = a.x + lambda * (b.x - a.x);
            res.y = a.y + lambda * (b.y - a.y);
            return res;
        }
        /* return (p1-p0)x(p2-p0), the area of the parallelogram */
        static double dpara(dPoint p0, dPoint p1, dPoint p2)
        {
            double x1, y1, x2, y2;

            x1 = p1.x - p0.x;
            y1 = p1.y - p0.y;
            x2 = p2.x - p0.x;
            y2 = p2.y - p0.y;

            return x1 * y2 - x2 * y1;
        }

        /* ddenom/dpara have the property that the square of radius 1 centered
           at p1 intersects the line p0p2 iff |dpara(p0,p1,p2)| <= ddenom(p0,p2) */
        static double ddenom(dPoint p0, dPoint p2)
        {
            iPoint r = dorth_infty(p0, p2);

            return r.y * (p2.x - p0.x) - r.x * (p2.y - p0.y);
        }

        /* return 1 if a <= b < c < a, in a cyclic sense (mod n) */
        static bool cyclic(int a, int b, int c)
        {
            if (a <= c)
            {
                return (a <= b && b < c);
            }
            else
            {
                return (a <= b || b < c);
            }
        }
        /* determine the center and slope of the line i..j. Assume i<j. Needs
        "sum" components of p to be set. */
        static void pointslope(Path pp, int i, int j, ref dPoint ctr, ref dPoint dir)
        {
            /* assume i<j */

            int n = pp.pt.Length;
            SumStruct[] sums = pp.Sums;


            double x, y, x2, xy, y2;
            double k;
            double a, b, c, lambda2, l;
            int r = 0; /* rotations from i to j */

            while (j >= n)
            {
                j -= n;
                r += 1;
            }
            while (i >= n)
            {
                i -= n;
                r -= 1;
            }
            while (j < 0)
            {
                j += n;
                r -= 1;
            }
            while (i < 0)
            {
                i += n;
                r += 1;
            }

            x = sums[j + 1].x - sums[i].x + r * sums[n].x;
            y = sums[j + 1].y - sums[i].y + r * sums[n].y;
            x2 = sums[j + 1].x2 - sums[i].x2 + r * sums[n].x2;
            xy = sums[j + 1].xy - sums[i].xy + r * sums[n].xy;
            y2 = sums[j + 1].y2 - sums[i].y2 + r * sums[n].y2;
            k = j + 1 - i + r * n;

            ctr.x = x / k;
            ctr.y = y / k;

            a = (x2 - (double)x * x / k) / k;
            b = (xy - (double)x * y / k) / k;
            c = (y2 - (double)y * y / k) / k;

            lambda2 = (a + c + Math.Sqrt((a - c) * (a - c) + 4 * b * b)) / 2; /* larger e.value */

            /* now find e.vector for lambda2 */
            a -= lambda2;
            c -= lambda2;

            if (Math.Abs(a) >= Math.Abs(c))
            {
                l = Math.Sqrt(a * a + b * b);
                if (l != 0)
                {
                    dir.x = -b / l;
                    dir.y = a / l;
                }
            }
            else
            {
                l = Math.Sqrt(c * c + b * b);
                if (l != 0)
                {
                    dir.x = -c / l;
                    dir.y = b / l;
                }
            }
            if (l == 0)
            {
                dir.x = dir.y = 0;   /* sometimes this can happen when k=4:
			      the two eigenvalues coincide */
            }
        }
        /* integer arithmetic */
        static int sign(int x) { return ((x) > 0 ? 1 : (x) < 0 ? -1 : 0); }
        static int sign(double x) { return ((x) > 0 ? 1 : (x) < 0 ? -1 : 0); }
        static int abs(int a) { return ((a) > 0 ? (a) : -(a)); }
        static int min(int a, int b) { return ((a) < (b) ? (a) : (b)); }
        static int max(int a, int b) { return ((a) > (b) ? (a) : (b)); }
        static int sq(int a) { return ((a) * (a)); }
        static int cu(int a) { return ((a) * (a) * (a)); }

        static int mod(int a, int n)
        {
            return a >= n ? a % n : a >= 0 ? a : n - 1 - (-1 - a) % n;
        }
        static int floordiv(int a, int n)
        {
            return a >= 0 ? a / n : -1 - (-1 - a) / n;
        }


        #endregion



        /// <summary>
        /// The MonotonInterval defines a structure related to an iPoint array.
        /// For each index i,j with 
        /// from &lt;= i &lt; j &lt;= to 
        /// in a cyclic sense is iPointArray[i].y &lt;= iPointArray[j].y if Increasing is true,
        /// else is iPointArray[i].y &gt;= iPointArray[j].y.
        /// 

        /// </summary>
        class MonotonInterval
        {
            public bool Increasing;
            public int from;
            public int to;
            public void ResetCurrentID(int modulo)
            {
                if (!Increasing)
                    CurrentID = mod(Min() + 1, modulo);
                else
                    CurrentID = Min();
            }

            public int CurrentID; // only used by Invert

            public MonotonInterval(bool Increasing, int from, int to)
            {
                this.Increasing = Increasing;
                this.from = from;
                this.to = to;
            }
            public int Min()
            {
                if (Increasing) return from;
                return to;
            }
            public int MinY(iPoint[] Pts)
            {
                return Pts[Min()].y;
            }
            public int MaxY(iPoint[] Pts)
            {
                return Pts[Max()].y;
            }
            public int Max()
            {
                if (!Increasing) return from;
                return to;
            }
        }

        #endregion
        #region Static function of Potrace


        /// <summary>
        /// 
        /// Produces a binary Matrix with Dimensions b.Width+2 and b.Height +2, where
        /// the Border ( of width) in the Matrix is filled with 'true' -values.
        /// On this way we avoid a lot of boundsinequalities.
        /// For the threshold, we take the Maximum of (R,G,B ) of a Pixel at x,y. If this is less then the threshold the resultMatrix at x+1, y+1 is filled with
        /// false else with true.
        /// 
        /// </summary>
        /// <param name="b"> A Bitmap, which will be transformed to a binary Matrix</param>
        /// <param name="_treshold">Gives a threshold ( between 1 and 254 ) for Converting</param>
        /// <returns>Returns a binaray boolean Matrix </returns>
        public static bool[,] BitMapToBinary(Bitmap b, int _treshold)
        {

            BitmapData SourceData = b.LockBits(new Rectangle(0, 0, b.Width, b.Height), System.Drawing.Imaging.ImageLockMode.ReadOnly, System.Drawing.Imaging.PixelFormat.Format24bppRgb);
            // inflated Result

            bool[,] Result = new bool[b.Width + 2, b.Height + 2];
            int SourceStride = SourceData.Stride;
            int H = b.Height;
            int W = b.Width;
            unsafe
            {
                byte* SourcePtr = (byte*)(void*)SourceData.Scan0;
                int Ydisp = 0;
                for (int y = 0; y < H; y++)
                {
                    for (int x = 0; x < W; x++)
                        if (Math.Max(
                            Math.Max(SourcePtr[x * 3 + 2 + Ydisp], SourcePtr[x * 3 + 1 + Ydisp]),
                            SourcePtr[x * 3 + 0 + Ydisp]) < _treshold)
                            Result[x + 1, y + 1] = false;
                        else
                            Result[x + 1, y + 1] = true;
                    Ydisp = Ydisp + SourceStride;
                }
            }
            b.UnlockBits(SourceData);
            // White Border
            for (int x = 0; x < Result.GetLength(0); x++)
            {
                Result[x, 0] = true;
                Result[x, Result.GetLength(1) - 1] = true;
            }
            for (int y = 1; y < Result.GetLength(1) - 1; y++)
            {
                Result[0, y] = true;
                Result[Result.GetLength(0) - 1, y] = true;
            }

            return Result;

        }
        /// <summary>
        /// Makes a Black and White Bitmap from the Data of a Binarymatrix.
        /// Value with 'true' returns a white Pixel such with 'false' a Black pixel.
        /// </summary>
        ///<param name="IgnoreBorder">If this value is set then a Border with 1 Pixel is ignored</param>
        /// <param name="Matrix">A Binary Matrix, which have boolean values</param>
        /// <returns>Returns a Black and white Image </returns>
        public static Bitmap BinaryToBitmap(bool[,] Matrix, bool IgnoreBorder)
        {
            int W = Matrix.GetLength(0);
            int H = Matrix.GetLength(1);
            if (IgnoreBorder)
            {
                W = W - 2;
                H = H - 2;
            }

            Bitmap OutPutImage = new Bitmap(W, H);
            BitmapData CopyData = OutPutImage.LockBits(new Rectangle(0, 0, OutPutImage.Width, OutPutImage.Height), ImageLockMode.ReadWrite, PixelFormat.Format24bppRgb);
            int stride = CopyData.Stride;
            int d = 0;
            if (IgnoreBorder) d = 1;

            unsafe
            {

                byte* DestPtr = (byte*)(void*)CopyData.Scan0;
                for (int i = 0; i < W; i++)
                    for (int j = 0; j < H; j++)
                    {
                        if (Matrix[i + d, j + d])
                        {
                            DestPtr[i * 3 + j * stride] = 255;
                            DestPtr[i * 3 + j * stride + 1] = 255;
                            DestPtr[i * 3 + j * stride + 2] = 255;
                        }
                        else
                        {
                            DestPtr[i * 3 + j * stride] = 0;
                            DestPtr[i * 3 + j * stride + 1] = 0;
                            DestPtr[i * 3 + j * stride + 2] = 0;

                        }
                    }
            }
            OutPutImage.UnlockBits(CopyData);
            return OutPutImage;
        }
        /// <summary>
        /// Searches a x and a y such that source[x,y] = true and source[x+1,y] false.
        /// If this not exists, false will be returned else the result is true. 
        /// 
        /// </summary>
        /// <param name="source">Is a Binary Matrix, which is produced by <see cref="BitMapToBinary"/>
        /// <param name="x">x index in the source Matrix</param>
        /// <param name="y">y index in the source Matrix</param>
        private static bool FindNext(bool[,] Matrix, ref int x, ref int y)
        {
            for (y = 1; y < Matrix.GetLength(1) - 1; y++)
                for (x = 0; x < Matrix.GetLength(0) - 1; x++)
                    if (!Matrix[x + 1, y]) // black found
                        return true;
            x = -1;
            return false;
        }
        // <summary>
        /// Searches a x and a y inside the Path P such that source[x,y] = true and source[x+1,y] false.
        /// If this not exists, false will be returned else the result is true. 
        /// 
        /// </summary>
        /// <param name="source">Is a Binary Matrix, which is produced by <see cref="BitMapToBinary"/>
        /// <param name="x">x index in the source Matrix</param>
        /// <param name="y">y index in the source Matrix</param>
        static bool FindNext(bool[,] Matrix, ref int x, ref int y, Path P)
        {
            int i = 0;
            int n = P.pt.Length;
            ArrayList MonotonIntervals = P.MonotonIntervals;
            if (MonotonIntervals.Count == 0) return false;
            MonotonInterval MI = (MonotonInterval)MonotonIntervals[0];
            MI.ResetCurrentID(n);
            y = P.pt[MI.CurrentID].y;
            ArrayList CurrentIntervals = new ArrayList();
            CurrentIntervals.Add(MI);
            MI.CurrentID = MI.Min();

            while ((i + 1 < MonotonIntervals.Count) && (((MonotonInterval)MonotonIntervals[i + 1]).MinY(P.pt) == y))
            {
                MI = (MonotonInterval)MonotonIntervals[i + 1];
                MI.ResetCurrentID(n);
                CurrentIntervals.Add(MI);
                i++;
            }

            while (CurrentIntervals.Count > 0)
            {
                for (int k = 0; k < CurrentIntervals.Count - 1; k++)
                {
                    int x1 = P.pt[((MonotonInterval)CurrentIntervals[k]).CurrentID].x + 1;
                    int x2 = P.pt[((MonotonInterval)CurrentIntervals[k + 1]).CurrentID].x;

                    for (x = x1; x <= x2; x++)
                        if (!Matrix[x, y])
                        {
                            x--;
                            return true;
                        }
                    k++;
                }

                y++;
                for (int j = CurrentIntervals.Count - 1; j >= 0; j--)
                {

                    MonotonInterval M = (MonotonInterval)CurrentIntervals[j];

                    if (y > M.MaxY(P.pt))
                    {
                        CurrentIntervals.RemoveAt(j);
                        continue;
                    }
                    int CID = M.CurrentID;
                    do
                    {
                        if (M.Increasing)
                            CID = mod(CID + 1, n);
                        else
                            CID = mod(CID - 1, n);
                    }
                    while (P.pt[CID].y < y);
                    M.CurrentID = CID;
                }
                // Add Items of MonotonIntervals with Miny==y
                while ((i + 1 < MonotonIntervals.Count) && (((MonotonInterval)MonotonIntervals[i + 1]).MinY(P.pt) == y))
                {
                    MonotonInterval NewInt = (MonotonInterval)MonotonIntervals[i + 1];
                    int j = 0;
                    // search the correct x-Position
                    int _x = P.pt[NewInt.Min()].x;
                    while ((j < CurrentIntervals.Count) && (_x > P.pt[((MonotonInterval)CurrentIntervals[j]).CurrentID].x)) j++;
                    CurrentIntervals.Insert(j, NewInt);
                    NewInt.ResetCurrentID(n);
                    i++;
                }
            }
            return false;
        }

        /* Apply quadratic form Q to vector w = (w.x,w.y) */
        static double quadform(double[,] Q, dPoint w)
        {
            double[] v ={ w.x, w.y, 1 };
            int i, j;
            double sum = 0;
            for (i = 0; i < 3; i++)
            {
                for (j = 0; j < 3; j++)
                {
                    sum += v[i] * Q[i, j] * v[j];
                }
            }
            return sum;
        }



        /*  */
        /// <summary>
        /// Compute a path in the binary matrix.
        /// Start path at the point (x0,x1), which must be an upper left corner
        /// of the path. Also compute the area enclosed by the path. Return a
        /// new path_t object, or NULL on error (note that a legitimate path
        /// cannot have length 0). 
        /// We omit turnpolicies and sign
        /// </summary>
        /// <param name="Matrix">Binary Matrix</param>
        /// <returns></returns>
        static Path findpath(bool[,] Matrix, iPoint Start)
        {
            ArrayList L = new ArrayList();



            direction Dir = direction.North;
            int x;
            int y;
            int area = 0;
            int diry = -1;
            x = Start.x;
            y = Start.y;

            do
            {
                // area += x * diry;
                L.Add(new iPoint(x, y));
                int _y = y;
                findNextTrace(Matrix, ref x, ref y, ref Dir);
                diry = _y - y;
                area += x * diry;
            }
            while ((x != Start.x) || (y != Start.y));

            if (L.Count == 0) return null;
            Path result = new Path();
            result.pt = new iPoint[L.Count];
            result.area = area;

            for (int i = 0; i < L.Count; i++) result.pt[i] = (iPoint)L[i];

            // Shift 1 to be compatible with Potrace

            if (result.pt.Length > 0)
            {
                iPoint P = result.pt[result.pt.Length - 1];
                for (int i = result.pt.Length - 1; i >= 0; i--)
                {
                    if (i > 0)
                        result.pt[i] = result.pt[i - 1];
                    else
                        result.pt[0] = P;
                }
            }



            result.MonotonIntervals = GetMonotonIntervals(result.pt);
            


            return result;
        }

        static void findNextTrace(bool[,] Matrix, ref int x, ref int y, ref direction Dir)
        {
            switch (Dir)
            {
                case direction.West:
                    {
                        if (!Matrix[x + 1, y + 1])
                        {
                            y++;
                            Dir = direction.North;
                        }
                        else

                            if (!Matrix[x + 1, y])
                            {
                                x++;
                                Dir = direction.West;
                            }
                            else
                            {
                                y--;
                                Dir = direction.South;
                            }
                        break;
                    }

                case direction.South:
                    {
                        if (!Matrix[x + 1, y])
                        {
                            x++;
                            Dir = direction.West;
                        }
                        else
                            if (!Matrix[x, y])
                            {
                                y--;
                                Dir = direction.South;
                            }
                            else
                            {
                                x--;
                                Dir = direction.East;
                            }
                        break;
                    }
                case direction.East:
                    {
                        if (!Matrix[x, y])
                        {
                            y--;
                            Dir = direction.South;
                        }
                        else

                            if (!Matrix[x, y + 1])
                            {
                                x--;
                                Dir = direction.East;
                            }
                            else
                            {
                                y++;
                                Dir = direction.North;
                            }
                        break;
                    }

                case direction.North:
                    {
                        if (!Matrix[x, y + 1])
                        {
                            x--;
                            Dir = direction.East;
                        }
                        else
                            if (!Matrix[x + 1, y + 1])
                            {
                                y++;
                                Dir = direction.North;
                            }
                            else
                            {
                                x++;
                                Dir = direction.West;
                            }
                        break;
                    }
            }
        }

        static ArrayList GetMonotonIntervals(iPoint[] Pts)
        {

            ArrayList result = new ArrayList();
            int n = Pts.Length;
            if (n == 0) return result;
            ArrayList L = new ArrayList();

            //----- Start with Strong Monoton (Pts[i].y < Pts[i+1].y) or (Pts[i].y > Pts[i+1].y)
            int FirstStrongMonoton = 0;
            while (Pts[FirstStrongMonoton].y == Pts[FirstStrongMonoton + 1].y) FirstStrongMonoton++;
            bool Up = (Pts[FirstStrongMonoton].y < Pts[FirstStrongMonoton + 1].y);
            MonotonInterval Interval = new MonotonInterval(Up, FirstStrongMonoton, FirstStrongMonoton);
            L.Add(Interval);
            int i = FirstStrongMonoton;
            do
            {
                // Interval.to = i;
                if ((Pts[i].y == Pts[mod(i + 1, n)].y) || (Up == (Pts[i].y < Pts[mod(i + 1, n)].y)))
                    Interval.to = i;
                else
                {
                    Up = (Pts[i].y < Pts[mod(i + 1, n)].y);
                    Interval = new MonotonInterval(Up, i, i);
                    L.Add(Interval);
                }
                i = mod(i + 1, n);
            }
            while (i != FirstStrongMonoton);

            if (L.Count / 2 * 2 != L.Count)
            {// Connect the Last with first 
                MonotonInterval M0 = (MonotonInterval)L[0];
                MonotonInterval ML = (MonotonInterval)L[L.Count - 1];
                M0.from = ML.from;
                L.RemoveAt(L.Count - 1);
            }

            //----- order now by the min y - value of interval to result 
            // and as second Key by the x-value
            //
            while (L.Count > 0)
            {
                MonotonInterval M = (MonotonInterval)L[0];
                i = 0;
                // order by y-value
                while ((i < result.Count) && (Pts[M.Min()].y > Pts[((MonotonInterval)result[i]).Min()].y)) i++;
                // order by x- value as second Key
                while ((i < result.Count) && (Pts[M.Min()].y == Pts[((MonotonInterval)result[i]).Min()].y) &&
                    (Pts[M.Min()].x > (Pts[((MonotonInterval)result[i]).Min()].x))) i++;
                result.Insert(i, M);
                L.RemoveAt(0);
            }
            return result;
        }

        static void Xor_Path(bool[,] Matrix, Path P)
        {
            int i = 0;
            int n = P.pt.Length;
            ArrayList MonotonIntervals = P.MonotonIntervals;
            if (MonotonIntervals.Count == 0) return;
            MonotonInterval MI = (MonotonInterval)MonotonIntervals[0];
            MI.ResetCurrentID(n);
            int y = P.pt[MI.CurrentID].y;
            ArrayList CurrentIntervals = new ArrayList();
            CurrentIntervals.Add(MI);
            MI.CurrentID = MI.Min();

            while ((i + 1 < MonotonIntervals.Count) && (((MonotonInterval)MonotonIntervals[i + 1]).MinY(P.pt) == y))
            {
                MI = (MonotonInterval)MonotonIntervals[i + 1];
                MI.ResetCurrentID(n);
                CurrentIntervals.Add(MI);
                i++;
            }

            while (CurrentIntervals.Count > 0)
            {   // invertLine
                for (int k = 0; k < CurrentIntervals.Count - 1; k++)
                {
                    int x1 = P.pt[((MonotonInterval)CurrentIntervals[k]).CurrentID].x + 1;
                    int x2 = P.pt[((MonotonInterval)CurrentIntervals[k + 1]).CurrentID].x;
                    for (int x = x1; x <= x2; x++) Matrix[x, y] = !Matrix[x, y];
                    k++;
                }

                y++;
                for (int j = CurrentIntervals.Count - 1; j >= 0; j--)
                {

                    MonotonInterval M = (MonotonInterval)CurrentIntervals[j];

                    if (y > M.MaxY(P.pt))
                    {
                        CurrentIntervals.RemoveAt(j);
                        continue;
                    }
                    int CID = M.CurrentID;
                    do
                    {
                        if (M.Increasing)
                            CID = mod(CID + 1, n);
                        else
                            CID = mod(CID - 1, n);
                    }
                    while (P.pt[CID].y < y);
                    M.CurrentID = CID;
                }
                // Add Items of MonotonIntervals with Down.y==y
                while ((i + 1 < MonotonIntervals.Count) && (((MonotonInterval)MonotonIntervals[i + 1]).MinY(P.pt) == y))
                {
                    MonotonInterval NewInt = (MonotonInterval)MonotonIntervals[i + 1];
                    int j = 0;
                    // search the correct x-Position
                    int _x = P.pt[NewInt.Min()].x;
                    while ((j < CurrentIntervals.Count) && (_x > P.pt[((MonotonInterval)CurrentIntervals[j]).CurrentID].x)) j++;
                    CurrentIntervals.Insert(j, NewInt);
                    NewInt.ResetCurrentID(n);
                    i++;
                }
            }
        }

        /* ---------------------------------------------------------------------- */
        /*  */
        /// <summary>
        ///Preparation: fill in the sum* fields of a path (used for later
        ///rapid summing). 
        /// </summary>
        /// <param name="pp">Path for which the preparation will be done</param>
        /// <returns></returns>
        static void calc_sums(Path pp)
        {
            int i, x, y;
            int n = pp.pt.Length;
            pp.Sums = new SumStruct[n + 1];


            // origin 
            int x0 = pp.pt[0].x;
            int y0 = pp.pt[0].y;

            // preparatory computation for later fast summing 
            //pp->sums[0].x2 = pp->sums[0].xy = pp->sums[0].y2 = pp->sums[0].x = pp->sums[0].y = 0;
            pp.Sums[0].x2 = pp.Sums[0].xy = pp.Sums[0].y2 = pp.Sums[0].x = pp.Sums[0].y = 0;

            for (i = 0; i < n; i++)
            {
                x = pp.pt[i].x - x0;
                y = pp.pt[i].y - y0;
                pp.Sums[i + 1].x = pp.Sums[i].x + x;
                pp.Sums[i + 1].y = pp.Sums[i].y + y;
                pp.Sums[i + 1].x2 = pp.Sums[i].x2 + x * x;
                pp.Sums[i + 1].xy = pp.Sums[i].xy + x * y;
                pp.Sums[i + 1].y2 = pp.Sums[i].y2 + y * y;
            }
        }
        /* ---------------------------------------------------------------------- */
        /* Stage 2: calculate the optimal polygon (Sec. 2.2.2-2.2.4). */

        /* Auxiliary function: calculate the penalty of an edge from i to j in
           the given path. This needs the "lon" and "sum*" data. */

        static double penalty3(Path pp, int i, int j)
        {
            int n = pp.pt.Length;

            /* assume 0<=i<j<=n  */
            double x, y, x2, xy, y2;
            double k;
            double a, b, c, s;
            double px, py, ex, ey;
            SumStruct[] sums = pp.Sums;
            iPoint[] pt = pp.pt;

            int r = 0; /* rotations from i to j */
            if (j >= n)
            {
                j -= n;
                r += 1;
            }


            x = sums[j + 1].x - sums[i].x + r * sums[n].x;
            y = sums[j + 1].y - sums[i].y + r * sums[n].y;
            x2 = sums[j + 1].x2 - sums[i].x2 + r * sums[n].x2;
            xy = sums[j + 1].xy - sums[i].xy + r * sums[n].xy;
            y2 = sums[j + 1].y2 - sums[i].y2 + r * sums[n].y2;
            k = j + 1 - i + r * n;

            px = (pt[i].x + pt[j].x) / 2.0 - pt[0].x;
            py = (pt[i].y + pt[j].y) / 2.0 - pt[0].y;
            ey = (pt[j].x - pt[i].x);
            ex = -(pt[j].y - pt[i].y);

            a = ((x2 - 2 * x * px) / k + px * px);
            b = ((xy - x * py - y * px) / k + px * py);
            c = ((y2 - 2 * y * py) / k + py * py);

            s = ex * ex * a + 2 * ex * ey * b + ey * ey * c;

            return Math.Sqrt(s);
        }

        static void calc_lon(Path pp)
        {

            int i, j, k, k1;
            int a, b, c, d;
            int[] ct = { 0, 0, 0, 0 };
            int dir;
            iPoint[] constraint = new iPoint[2];
            iPoint cur;
            iPoint off;
            iPoint dk;  /* direction of k-k1 */
            iPoint[] pt = pp.pt;


            int n = pt.Length;
            int[] Pivot = new int[n];
            int[] nc = new int[n];
            /* initialize the nc data structure. Point from each point to the
                 furthest future point to which it is connected by a vertical or
                 horizontal segment. We take advantage of the fact that there is
                 always a direction change at 0 (due to the path decomposition
                 algorithm). But even if this were not so, there is no harm, as
                 in practice, correctness does not depend on the word "furthest"
                 above.  */


            k = 0;
            for (i = n - 1; i >= 0; i--)
            {
                if (pt[i].x != pt[k].x && pt[i].y != pt[k].y)
                {
                    k = i + 1;  /* necessarily i<n-1 in this case */
                }
                nc[i] = k;
            }


            pp.Lon = new int[n];
            /* determine pivot points: for each i, let pivk[i] be the furthest k
    such that all j with i<j<k lie on a line connecting i,k. */

            for (i = n - 1; i >= 0; i--)
            {

                ct[0] = ct[1] = ct[2] = ct[3] = 0;

                /* keep track of "directions" that have occurred */
                dir = (3 + 3 * (pt[mod(i + 1, n)].x - pt[i].x) + (pt[mod(i + 1, n)].y - pt[i].y)) / 2;
                ct[dir]++;

                constraint[0].x = 0;
                constraint[0].y = 0;
                constraint[1].x = 0;
                constraint[1].y = 0;

                /* find the next k such that no straight line from i to k */
                k = nc[i];
                k1 = i;
                while (true)
                {
                    dir = (3 + 3 * sign(pt[k].x - pt[k1].x) + sign(pt[k].y - pt[k1].y)) / 2;
                    ct[dir]++;


                    /* if all four "directions" have occurred, cut this path */
                    if ((ct[0] == 1) && (ct[1] == 1) && (ct[2] == 1) && (ct[3] == 1))
                    {
                        Pivot[i] = k1;
                        goto foundk;
                    }

                    cur.x = pt[k].x - pt[i].x;
                    cur.y = pt[k].y - pt[i].y;

                    /* see if current constraint is violated */
                    if (xprod(constraint[0], cur) < 0 || xprod(constraint[1], cur) > 0)
                    {
                        goto constraint_viol;
                    }

                    /* else, update constraint */
                    if (abs(cur.x) <= 1 && abs(cur.y) <= 1)
                    {
                        /* no constraint */
                    }
                    else
                    {
                        off.x = cur.x + ((cur.y >= 0 && (cur.y > 0 || cur.x < 0)) ? 1 : -1);
                        off.y = cur.y + ((cur.x <= 0 && (cur.x < 0 || cur.y < 0)) ? 1 : -1);
                        if (xprod(constraint[0], off) >= 0)
                        {
                            constraint[0] = off;
                        }
                        off.x = cur.x + ((cur.y <= 0 && (cur.y < 0 || cur.x < 0)) ? 1 : -1);
                        off.y = cur.y + ((cur.x >= 0 && (cur.x > 0 || cur.y < 0)) ? 1 : -1);
                        if (xprod(constraint[1], off) <= 0)
                        {
                            constraint[1] = off;
                        }
                    }
                    k1 = k;
                    k = nc[k1];
                    if (!cyclic(k, i, k1))
                    {
                        break;
                    }
                }
            constraint_viol:
                /* k1 was the last "corner" satisfying the current constraint, and
                   k is the first one violating it. We now need to find the last
                   point along k1..k which satisfied the constraint. */

                dk.x = sign(pt[k].x - pt[k1].x);
                dk.y = sign(pt[k].y - pt[k1].y);
                cur.x = pt[k1].x - pt[i].x;
                cur.y = pt[k1].y - pt[i].y;

                /* find largest integer j such that xprod(constraint[0], cur+j*dk)
                   >= 0 and xprod(constraint[1], cur+j*dk) <= 0. Use bilinearity
                   of xprod. */
                a = xprod(constraint[0], cur);
                b = xprod(constraint[0], dk);
                c = xprod(constraint[1], cur);
                d = xprod(constraint[1], dk);
                /* find largest integer j such that a+j*b>=0 and c+j*d<=0. This
                   can be solved with integer arithmetic. */
                j = int.MaxValue;
                if (b < 0)
                {
                    j = floordiv(a, -b);
                }
                if (d > 0)
                {
                    j = min(j, floordiv(-c, d));
                }
                Pivot[i] = mod(k1 + j, n);
            foundk:
                ;
            } /* for i */

            /* clean up: for each i, let lon[i] be the largest k such that for
               all i' with i<=i'<k, i'<k<=pivk[i']. */

            j = Pivot[n - 1];
            pp.Lon[n - 1] = j;

            for (i = n - 2; i >= 0; i--)
            {
                if (cyclic(i + 1, Pivot[i], j))
                {
                    j = Pivot[i];
                }
                pp.Lon[i] = j;

            }

            for (i = n - 1; cyclic(mod(i + 1, n), j, pp.Lon[i]); i--)
            {
                pp.Lon[i] = j;

            }




        }





        /* find the optimal polygon. Fill in the m and po components. Return 1
            on failure with errno set, else 0. Non-cyclic version: assumes i=0
            is in the polygon. Fixme: ### implement cyclic version. */


        static void bestpolygon(Path pp)
        {
            int i, j, m, k;
            int n = pp.pt.Length;
            double[] pen = new double[n + 1]; /* pen[n+1]: penalty vector */
            int[] prev = new int[n + 1];   /* prev[n+1]: best path pointer vector */
            int[] clip0 = new int[n];  /* clip0[n]: longest segment pointer, non-cyclic */
            int[] clip1 = new int[n + 1];  /* clip1[n+1]: backwards segment pointer, non-cyclic */
            int[] seg0 = new int[n + 1];    /* seg0[m+1]: forward segment bounds, m<=n */
            int[] seg1 = new int[n + 1];   /* seg1[m+1]: backward segment bounds, m<=n */

            double thispen;
            double best;
            int c;


            /* calculate clipped paths */
            for (i = 0; i < n; i++)
            {
                c = mod(pp.Lon[mod(i - 1, n)] - 1, n);

                if (c == i)
                {
                    c = mod(i + 1, n);
                }
                if (c < i)
                {
                    clip0[i] = n;
                }
                else
                {
                    clip0[i] = c;
                }
            }

            /* calculate backwards path clipping, non-cyclic. j <= clip0[i] iff
            clip1[j] <= i, for i,j=0..n. */
            j = 1;
            for (i = 0; i < n; i++)
            {
                while (j <= clip0[i])
                {
                    clip1[j] = i;
                    j++;
                }
            }

            /* calculate seg0[j] = longest path from 0 with j segments */
            i = 0;
            for (j = 0; i < n; j++)
            {
                seg0[j] = i;
                i = clip0[i];
            }
            seg0[j] = n;
            m = j;

            /* calculate seg1[j] = longest path to n with m-j segments */
            i = n;
            for (j = m; j > 0; j--)
            {
                seg1[j] = i;
                i = clip1[i];
            }
            seg1[0] = 0;

            /* now find the shortest path with m segments, based on penalty3 */
            /* note: the outer 2 loops jointly have at most n interations, thus
            the worst-case behavior here is quadratic. In practice, it is
            close to linear since the inner loop tends to be short. */
            pen[0] = 0;
            for (j = 1; j <= m; j++)
            {
                for (i = seg1[j]; i <= seg0[j]; i++)
                {
                    best = -1;
                    for (k = seg0[j - 1]; k >= clip1[i]; k--)
                    {
                        thispen = penalty3(pp, k, i) + pen[k];
                        if (best < 0 || thispen < best)
                        {
                            prev[i] = k;
                            best = thispen;
                        }
                    }
                    pen[i] = best;
                }
            }


            /* read off shortest path */

            int[] B = new int[m];

            pp.po = new int[m];
            for (i = n, j = m - 1; i > 0; j--)
            {
                i = prev[i];
                B[j] = i;
            }

            /*   if ((m > 0) && ( mod(pp.Lon[m - 1]-1,n)<= B[1]))
               {// reduce
                   B[0] = B[m - 1];
                   pp.po = new int[m - 1];
                   for (i = 0; i < m - 1; i++)
                       pp.po[i] = B[i];

               }
               else
             */
            pp.po = B;




        }

        /* Stage 3: vertex adjustment (Sec. 2.3.1). */

        /* Adjust vertices of optimal polygon: calculate the intersection of
           the two "optimal" line segments, then move it into the unit square
           if it lies outside. Return 1 with errno set on error; 0 on
           success. */

        /* calculate "optimal" point-slope representation for each line
     segment */
        static void adjust_vertices(Path pp)
        {
            int m = pp.po.Length;
            int[] po = pp.po;
            iPoint[] pt = pp.pt;
            int n = pt.Length;


            int x0 = pt[0].x;
            int y0 = pt[0].y;

            dPoint[] ctr = new dPoint[m];      /* ctr[m] */
            dPoint[] dir = new dPoint[m];      /* dir[m] */
            //quadform_t *q = NULL;      /* q[m] */
            double[, ,] q = new double[m, 3, 3];
            double[] v = new double[3];
            double d;
            int i, j, k, l;
            dPoint s;
            pp.Curves = new privcurve(m);
            /* calculate "optimal" point-slope representation for each line
            segment */
            for (i = 0; i < m; i++)
            {
                j = po[mod(i + 1, m)];
                j = mod(j - po[i], n) + po[i];
                pointslope(pp, po[i], j, ref ctr[i], ref dir[i]);
            }
            /* represent each line segment as a singular quadratic form; the
                 distance of a point (x,y) from the line segment will be
                 (x,y,1)Q(x,y,1)^t, where Q=q[i]. */

            for (i = 0; i < m; i++)
            {
                d = dir[i].x * dir[i].x + dir[i].y * dir[i].y;

                if (d == 0.0)
                {
                    for (j = 0; j < 3; j++)
                    {
                        for (k = 0; k < 3; k++)
                        {
                            q[i, j, k] = 0;
                        }
                    }
                }
                else
                {
                    v[0] = dir[i].y;
                    v[1] = -dir[i].x;
                    v[2] = -v[1] * ctr[i].y - v[0] * ctr[i].x;
                    for (l = 0; l < 3; l++)
                    {
                        for (k = 0; k < 3; k++)
                        {
                            q[i, l, k] = v[l] * v[k] / d;
                        }
                    }
                }
            }
            /* now calculate the "intersections" of consecutive segments.
               Instead of using the actual intersection, we find the point
               within a given unit square which minimizes the square distance to
               the two lines. */
            for (i = 0; i < m; i++)
            {
                double[,] Q = new double[3, 3];
                dPoint w;
                double dx, dy;
                double det;
                double min, cand; /* minimum and candidate for minimum of quad. form */
                double xmin, ymin;	/* coordinates of minimum */
                int z;

                /* let s be the vertex, in coordinates relative to x0/y0 */
                s.x = pt[po[i]].x - x0;
                s.y = pt[po[i]].y - y0;

                /* intersect segments i-1 and i */

                j = mod(i - 1, m);

                /* add quadratic forms */
                for (l = 0; l < 3; l++)
                {
                    for (k = 0; k < 3; k++)
                    {
                        Q[l, k] = q[j, l, k] + q[i, l, k];
                    }
                }
                while (true)
                {
                    /* minimize the quadratic form Q on the unit square */
                    /* find intersection */
                    det = Q[0, 0] * Q[1, 1] - Q[0, 1] * Q[1, 0];
                    if (det != 0.0)
                    {
                        w.x = (-Q[0, 2] * Q[1, 1] + Q[1, 2] * Q[0, 1]) / det;
                        w.y = (Q[0, 2] * Q[1, 0] - Q[1, 2] * Q[0, 0]) / det;
                        break;
                    }

                    /* matrix is singular - lines are parallel. Add another,
                   orthogonal axis, through the center of the unit square */
                    if (Q[0, 0] > Q[1, 1])
                    {
                        v[0] = -Q[0, 1];
                        v[1] = Q[0, 0];
                    }
                    else if (Q[1, 1] != 0) // nur if (Q[1,1])
                    {
                        v[0] = -Q[1, 1];
                        v[1] = Q[1, 0];
                    }
                    else
                    {
                        v[0] = 1;
                        v[1] = 0;
                    }
                    d = v[0] * v[0] + v[1] * v[1];
                    v[2] = -v[1] * s.y - v[0] * s.x;
                    for (l = 0; l < 3; l++)
                    {
                        for (k = 0; k < 3; k++)
                        {
                            Q[l, k] += v[l] * v[k] / d;
                        }
                    }
                }
                dx = Math.Abs(w.x - s.x);
                dy = Math.Abs(w.y - s.y);
                if (dx <= .5 && dy <= .5)
                {
                    // - 1 because we have a additional border set to the bitmap
                    pp.Curves.vertex[i].x = w.x + x0;
                    pp.Curves.vertex[i].y = w.y + y0;


                    continue;
                }

                /* the minimum was not in the unit square; now minimize quadratic
                   on boundary of square */
                min = quadform(Q, s);
                xmin = s.x;
                ymin = s.y;

                if (Q[0, 0] == 0.0)
                {
                    goto fixx;
                }
                for (z = 0; z < 2; z++)
                {   /* value of the y-coordinate */
                    w.y = s.y - 0.5 + z;
                    w.x = -(Q[0, 1] * w.y + Q[0, 2]) / Q[0, 0];
                    dx = Math.Abs(w.x - s.x);
                    cand = quadform(Q, w);
                    if (dx <= .5 && cand < min)
                    {
                        min = cand;
                        xmin = w.x;
                        ymin = w.y;
                    }
                }
            fixx:
                if (Q[1, 1] == 0.0)
                {
                    goto corners;
                }
                for (z = 0; z < 2; z++)
                {   /* value of the x-coordinate */
                    w.x = s.x - 0.5 + z;
                    w.y = -(Q[1, 0] * w.x + Q[1, 2]) / Q[1, 1];
                    dy = Math.Abs(w.y - s.y);
                    cand = quadform(Q, w);
                    if (dy <= .5 && cand < min)
                    {
                        min = cand;
                        xmin = w.x;
                        ymin = w.y;
                    }
                }
            corners:
                /* check four corners */
                for (l = 0; l < 2; l++)
                {
                    for (k = 0; k < 2; k++)
                    {
                        w.x = s.x - 0.5 + l;
                        w.y = s.y - 0.5 + k;
                        cand = quadform(Q, w);
                        if (cand < min)
                        {
                            min = cand;
                            xmin = w.x;
                            ymin = w.y;
                        }
                    }
                }
                // - 1 because we have a additional border set to the bitmap
                pp.Curves.vertex[i].x = xmin + x0 - 1;
                pp.Curves.vertex[i].y = ymin + y0 - 1;
                continue;
            }


        }
        /* ---------------------------------------------------------------------- */
        /* Stage 4: smoothing and corner analysis (Sec. 2.3.3) */

        /* Always succeeds and returns 0 */
        static void smooth(privcurve curve, int sign, double alphamax)
        {
            int m = curve.n;

            int i, j, k;
            double dd, denom, alpha;
            dPoint p2, p3, p4;

            if (sign == '-')
            {
                /* reverse orientation of negative paths */
                for (i = 0, j = m - 1; i < j; i++, j--)
                {
                    dPoint tmp;
                    tmp = curve.vertex[i];
                    curve.vertex[i] = curve.vertex[j];
                    curve.vertex[j] = tmp;
                }
            }

            /* examine each vertex and find its best fit */
            for (i = 0; i < m; i++)
            {
                j = mod(i + 1, m);
                k = mod(i + 2, m);
                p4 = interval(1 / 2.0, curve.vertex[k], curve.vertex[j]);

                denom = ddenom(curve.vertex[i], curve.vertex[k]);
                if (denom != 0.0)
                {
                    dd = dpara(curve.vertex[i], curve.vertex[j], curve.vertex[k]) / denom;
                    dd = Math.Abs(dd);
                    alpha = dd > 1 ? (1 - 1.0 / dd) : 0;
                    alpha = alpha / 0.75;
                }
                else
                {
                    alpha = 4 / 3.0;
                }
                curve.alpha0[j] = alpha;	 /* remember "original" value of alpha */
              
                if (alpha > alphamax)
                {  /* pointed corner */
                    curve.tag[j] = POTRACE_CORNER;
                    //curve.c[j][1] = curve->vertex[j];
                    curve.ControlPoints[j, 1] = curve.vertex[j];
                    curve.ControlPoints[j, 2] = p4;
                }
                else
                {
                    if (alpha < 0.55)
                    {
                        alpha = 0.55;
                    }
                    else if (alpha > 1)
                    {
                        alpha = 1;
                    }
                    p2 = interval(.5 + .5 * alpha, curve.vertex[i], curve.vertex[j]);
                    p3 = interval(.5 + .5 * alpha, curve.vertex[k], curve.vertex[j]);
                    curve.tag[j] = POTRACE_CURVETO;
                    curve.ControlPoints[j, 0] = p2;
                    curve.ControlPoints[j, 1] = p3;
                    curve.ControlPoints[j, 2] = p4;
                }
                curve.alpha[j] = alpha;	/* store the "cropped" value of alpha */
                curve.beta[j] = 0.5;
            }


        }
        /* ---------------------------------------------------------------------- */
        /* Stage 5: Curve optimization (Sec. 2.4) */

        /* a private type for the result of opti_penalty */
        struct opti
        {
            public double pen;	   /* penalty */
            public dPoint[] c;   /* curve parameters */
            public double t, s;	   /* curve parameters */
            public double alpha;	   /* curve parameter */
        };

        /* calculate best fit from i+.5 to j+.5.  Assume i<j (cyclically).
           Return 0 and set badness and parameters (alpha, beta), if
           possible. Return 1 if impossible. */
        static bool opti_penalty(Path pp, int i, int j, ref opti res, double opttolerance, int[] convc, double[] areac)
        {
            int m = pp.Curves.n;
            int k, k1, k2, conv, i1;
            double area, alpha, d, d1, d2;
            dPoint p0, p1, p2, p3, pt;
            double A, R, A1, A2, A3, A4;
            double s, t;

            /* check convexity, corner-freeness, and maximum bend < 179 degrees */

            if (i == j)
            {  /* sanity - a full loop can never be an opticurve */
                return true;
            }

            k = i;
            i1 = mod(i + 1, m);
            k1 = mod(k + 1, m);
            conv = convc[k1];
            if (conv == 0)
            {
                return true;
            }
            d = ddist(pp.Curves.vertex[i], pp.Curves.vertex[i1]);
            for (k = k1; k != j; k = k1)
            {
                k1 = mod(k + 1, m);
                k2 = mod(k + 2, m);
                if (convc[k1] != conv)
                {
                    return true;
                }
                if (sign(cprod(pp.Curves.vertex[i], pp.Curves.vertex[i1], pp.Curves.vertex[k1], pp.Curves.vertex[k2])) != conv)
                {
                    return true;
                }
                if (iprod1(pp.Curves.vertex[i], pp.Curves.vertex[i1], pp.Curves.vertex[k1], pp.Curves.vertex[k2]) < d * ddist(pp.Curves.vertex[k1], pp.Curves.vertex[k2]) * COS179)
                {
                    return true;
                }
            }

            /* the curve we're working in: */
            p0 = pp.Curves.ControlPoints[mod(i, m), 2];
            p1 = pp.Curves.vertex[mod(i + 1, m)];
            p2 = pp.Curves.vertex[mod(j, m)];
            p3 = pp.Curves.ControlPoints[mod(j, m), 2];

            /* determine its area */
            area = areac[j] - areac[i];
            area -= dpara(pp.Curves.vertex[0], pp.Curves.ControlPoints[i, 2], pp.Curves.ControlPoints[j, 2]) / 2;
            if (i >= j)
            {
                area += areac[m];
            }

            /* find intersection o of p0p1 and p2p3. Let t,s such that o =
               interval(t,p0,p1) = interval(s,p3,p2). Let A be the area of the
               triangle (p0,o,p3). */

            A1 = dpara(p0, p1, p2);
            A2 = dpara(p0, p1, p3);
            A3 = dpara(p0, p2, p3);
            /* A4 = dpara(p1, p2, p3); */
            A4 = A1 + A3 - A2;

            if (A2 == A1)
            {  /* this should never happen */
                return true;
            }

            t = A3 / (A3 - A4);
            s = A2 / (A2 - A1);
            A = A2 * t / 2.0;

            if (A == 0.0)
            {  /* this should never happen */
                return true;
            }

            R = area / A;	 /* relative area */
            alpha = 2 - Math.Sqrt(4 - R / 0.3);  /* overall alpha for p0-o-p3 curve */
            res.c = new dPoint[2];
            res.c[0] = interval(t * alpha, p0, p1);
            res.c[1] = interval(s * alpha, p3, p2);
            res.alpha = alpha;
            res.t = t;
            res.s = s;

            p1 = res.c[0];
            p2 = res.c[1];  /* the proposed curve is now (p0,p1,p2,p3) */

            res.pen = 0;

            /* calculate penalty */
            /* check tangency with edges */
            for (k = mod(i + 1, m); k != j; k = k1)
            {
                k1 = mod(k + 1, m);
                t = tangent(p0, p1, p2, p3, pp.Curves.vertex[k], pp.Curves.vertex[k1]);
                if (t < -.5)
                {
                    return true;
                }
                pt = bezier(t, p0, p1, p2, p3);
                d = ddist(pp.Curves.vertex[k], pp.Curves.vertex[k1]);
                if (d == 0.0)
                {  /* this should never happen */

                    return true;
                }
                d1 = dpara(pp.Curves.vertex[k], pp.Curves.vertex[k1], pt) / d;
                if (Math.Abs(d1) > opttolerance)
                {
                    return true;
                }
                if (iprod(pp.Curves.vertex[k], pp.Curves.vertex[k1], pt) < 0 || iprod(pp.Curves.vertex[k1], pp.Curves.vertex[k], pt) < 0)
                {
                    return true;
                }
                res.pen += d1 * d1;
            }

            /* check corners */
            for (k = i; k != j; k = k1)
            {
                k1 = mod(k + 1, m);
                t = tangent(p0, p1, p2, p3, pp.Curves.ControlPoints[k, 2], pp.Curves.ControlPoints[k1, 2]);
                if (t < -.5)
                {
                    return true;
                }
                pt = bezier(t, p0, p1, p2, p3);
                d = ddist(pp.Curves.ControlPoints[k, 2], pp.Curves.ControlPoints[k1, 2]);
                if (d == 0.0)
                {  /* this should never happen */
                    return true;
                }
                d1 = dpara(pp.Curves.ControlPoints[k, 2], pp.Curves.ControlPoints[k1, 2], pt) / d;
                d2 = dpara(pp.Curves.ControlPoints[k, 2], pp.Curves.ControlPoints[k1, 2], pp.Curves.vertex[k1]) / d;
                d2 *= 0.75 * pp.Curves.alpha[k1];
                if (d2 < 0)
                {
                    d1 = -d1;
                    d2 = -d2;
                }
                if (d1 < d2 - opttolerance)
                {
                    return true;
                }
                if (d1 < d2)
                {
                    res.pen += (d1 - d2) * (d1 - d2);
                }
            }

            return false;
        }
        private void i() { }

        /* optimize the path p, replacing sequences of Bezier segments by a
   single segment when possible. Return 0 on success, 1 with errno set
   on failure. */
        static void opticurve(Path pp, double opttolerance)
        {
            int m = pp.Curves.n;
            int[] pt = new int[m + 1];     /* pt[m+1] */
            double[] pen = new double[m + 1];  /* pen[m+1] */
            int[] len = new int[m + 1];     /* len[m+1] */
            opti[] opt = new opti[m + 1];    /* opt[m+1] */
            int[] convc = new int[m];       /* conv[m]: pre-computed convexities */
            double[] areac = new double[m + 1];  /* cumarea[m+1]: cache for fast area computation */


            int om;
            int i, j;
            bool r;
            opti o = new opti();
            dPoint p0;
            int i1;
            double area;
            double alpha;
            double[] s;
            double[] t;




            /* pre-calculate convexity: +1 = right turn, -1 = left turn, 0 = corner */
            for (i = 0; i < m; i++)
            {
                if (pp.Curves.tag[i] == POTRACE_CURVETO)
                {
                    convc[i] = sign(dpara(pp.Curves.vertex[mod(i - 1, m)], pp.Curves.vertex[i], pp.Curves.vertex[mod(i + 1, m)]));
                }
                else
                {
                    convc[i] = 0;
                }
            }

            /* pre-calculate areas */
            area = 0.0;
            areac[0] = 0.0;
            p0 = pp.Curves.vertex[0];
            for (i = 0; i < m; i++)
            {
                i1 = mod(i + 1, m);
                if (pp.Curves.tag[i1] == POTRACE_CURVETO)
                {
                    alpha = pp.Curves.alpha[i1];
                    area += 0.3 * alpha * (4 - alpha) * dpara(pp.Curves.ControlPoints[i, 2], pp.Curves.vertex[i1], pp.Curves.ControlPoints[i1, 2]) / 2;
                    area += dpara(p0, pp.Curves.ControlPoints[i, 2], pp.Curves.ControlPoints[i1, 2]) / 2;
                }
                areac[i + 1] = area;
            }

            pt[0] = -1;
            pen[0] = 0;
            len[0] = 0;

            /* Fixme: we always start from a fixed point -- should find the best
               curve cyclically ### */

            for (j = 1; j <= m; j++)
            {
                /* calculate best path from 0 to j */
                pt[j] = j - 1;
                pen[j] = pen[j - 1];
                len[j] = len[j - 1] + 1;

                for (i = j - 2; i >= 0; i--)
                {
                    r = opti_penalty(pp, i, mod(j, m), ref o, opttolerance, convc, areac);
                    if (r)
                    {
                        break;
                    }
                    if (len[j] > len[i] + 1 || (len[j] == len[i] + 1 && pen[j] > pen[i] + o.pen))
                    {
                        pt[j] = i;
                        pen[j] = pen[i] + o.pen;
                        len[j] = len[i] + 1;
                        opt[j] = o;
                    }
                }
            }
            om = len[m];
            pp.OptimizedCurves = new privcurve(om);

            s = new double[om];
            t = new double[om];


            j = m;
            for (i = om - 1; i >= 0; i--)
            {
                if (pt[j] == j - 1)
                {
                    pp.OptimizedCurves.tag[i] = pp.Curves.tag[mod(j, m)];
                    pp.OptimizedCurves.ControlPoints[i, 0] = pp.Curves.ControlPoints[mod(j, m), 0];
                    pp.OptimizedCurves.ControlPoints[i, 1] = pp.Curves.ControlPoints[mod(j, m), 1];
                    pp.OptimizedCurves.ControlPoints[i, 2] = pp.Curves.ControlPoints[mod(j, m), 2];
                    pp.OptimizedCurves.vertex[i] = pp.Curves.vertex[mod(j, m)];
                    pp.OptimizedCurves.alpha[i] = pp.Curves.alpha[mod(j, m)];
                    pp.OptimizedCurves.alpha0[i] = pp.Curves.alpha0[mod(j, m)];
                    pp.OptimizedCurves.beta[i] = pp.Curves.beta[mod(j, m)];
                    s[i] = t[i] = 1.0;
                }
                else
                {
                    pp.OptimizedCurves.tag[i] = POTRACE_CURVETO;
                    pp.OptimizedCurves.ControlPoints[i, 0] = opt[j].c[0];
                    pp.OptimizedCurves.ControlPoints[i, 1] = opt[j].c[1];
                    pp.OptimizedCurves.ControlPoints[i, 2] = pp.Curves.ControlPoints[mod(j, m), 2];
                    pp.OptimizedCurves.vertex[i] = interval(opt[j].s, pp.Curves.ControlPoints[mod(j, m), 2], pp.Curves.vertex[mod(j, m)]);
                    pp.OptimizedCurves.alpha[i] = opt[j].alpha;
                    pp.OptimizedCurves.alpha0[i] = opt[j].alpha;
                    s[i] = opt[j].s;
                    t[i] = opt[j].t;
                }
                j = pt[j];
            }

            /* calculate beta parameters */
            for (i = 0; i < om; i++)
            {
                i1 = mod(i + 1, om);
                pp.OptimizedCurves.beta[i] = s[i] / (s[i] + t[i1]);
            }

        }




        static void getContur(bool[,] bm, int x, int y, ArrayList plistp)
        {


            Path Contur = findpath(bm, new iPoint(x, y));

            Xor_Path(bm, Contur);
            ArrayList PolyPath = new ArrayList();
            // only area > turdsize is taken

            if (Contur.area > turdsize)
            {
                plistp.Add(PolyPath);
                PolyPath.Add(Contur); // Path with index 0 is a conture
            }


            while (FindNext(bm, ref x, ref y, Contur))
            {
                Path Hole = findpath(bm, new iPoint(x, y));
                //Path Hole = findpath(bm, x, y);
                Xor_Path(bm, Hole);
                if (Hole.area > turdsize)

                    PolyPath.Add(Hole); // Path with index > 0 is a hole,
                if (FindNext(bm, ref x, ref y, Hole))
                    getContur(bm, x, y, plistp);

            }

        }
        /// <summary>
        /// It is the main function, which yields the curveinformations related to a given binary bitmap.
        /// It fills the ArrayList ListOfCurveArrays with curvepathes. 
        /// Each of this pathes is an list of connecting curves.
        /// 
        /// Example:
        /// <pre>
        /// Call first:
        ///     ArrayList ListOfCurveArrays = new ArrayList();
        ///     potrace_trace(bm, ListOfCurveArrays);
        /// Paint the result:
        ///    GraphicsPath gp = new GraphicsPath();
        ///     for (int i = 0; i &lt; ListOfCurveArrays.Count; i++)
        ///    {
        ///        ArrayList CurveArray = (ArrayList)ListOfCurveArrays[i];
        ///        GraphicsPath Contour=null;
        ///        GraphicsPath Hole = null;
        ///        GraphicsPath Current=null;
        ///        for (int j = 0; j &lt; CurveArray.Count; j++)
        ///        {
        ///            if (j == 0)
        ///            {
        ///                Contour = new GraphicsPath();
        ///                Current = Contour;
        ///            }
        ///            else
        ///            {
        ///                Hole = new GraphicsPath();
        ///                Current = Hole;
        ///             }
        ///            Potrace.Curve[] Curves = (Curve[])CurveArray[j];
        ///            for (int k = 0; k &lt; Curves.Length; k++)
        ///            {
        ///                if (Curves[k].Kind == Potrace.CurveKind.Bezier)
        ///                    Current.AddBezier((float)Curves[k].A.x, (float)Curves[k].A.y, (float)Curves[k].ControlPointA.x, (float)Curves[k].ControlPoint.y,
        ///                                      (float)Curves[k].ControlPointB.x, (float)Curves[k].ControlPointB.y, (float)Curves[k].B.x, (float)Curves[k].B.y);
        ///                else
        ///                    Current.AddLine((float)Curves[k].A.x, (float)Curves[k].A.y, (float)Curves[k].B.x, (float)Curves[k].B.y);
        ///            }
        ///            if (j > 0) Contour.AddPath(Hole, false);
        ///        }
        ///        gp.AddPath(Contour, false);
        ///    }
        ///     // any Graphic g
        ///    Graphics g = CreateGraphics();
        ///     // Paint the fill
        ///    g.FillPath(Brushes.Black, gp);
        ///     // Paint the border
        ///    g.DrawPath(Pens.Red,gp);
        /// </pre>
        /// </summary>
        /// <param name="ListOfCurveArrays">A list in which the curveinformations will be stored.</param>
        /// 
        /// <param name="bm">A binary bitmap, which holds the pixelinformation about the image.</param>

        public static void potrace_trace(bool[,] bm, ArrayList ListOfCurveArrays)
        {
            ArrayList plistp = new ArrayList();
            bm_to_pathlist(bm, plistp);
            process_path(plistp);
            PathList_to_ListOfCurveArrays(plistp, ListOfCurveArrays);
        }
        static void AddCurve(ArrayList Curves, dPoint A, dPoint ControlPointA, dPoint ControlPointB, dPoint B)
        {
            //   Curves.Add(new Curve(CurveKind.Bezier, A, ControlPointA, ControlPointB, B));
            //   return;
            CurveKind Kind;
            if ((Math.Abs(xprod(new dPoint(ControlPointA.x - A.x, ControlPointA.y - A.y),
                                   new dPoint(B.x - A.x, B.y - A.y))) < 0.01) &&
                               (Math.Abs(xprod(new dPoint(ControlPointB.x - B.x, ControlPointB.y - B.y),
                                   new dPoint(B.x - A.x, B.y - A.y))) < 0.01))
                Kind = CurveKind.Line;
            else
                Kind = CurveKind.Bezier;
            /*    Curves.Add(new Curve(Kind,A,ControlPointA,ControlPointB,B));
                return;*/
            if ((Kind == CurveKind.Line))
            {
                if ((Curves.Count > 0) && (((Curve)Curves[Curves.Count - 1]).Kind == CurveKind.Line))
                {
                    Curve C = (Curve)Curves[Curves.Count - 1];
                    if ((Math.Abs(xprod(new dPoint(C.B.x - C.A.x, C.B.y - C.A.y), new dPoint(B.x - A.x, B.y - A.y))) < 0.01) &&
                        (iprod(C.B, C.A, B) < 0))
                        Curves[Curves.Count - 1] = new Curve(Kind, C.A, C.A, C.A, B);
                    else
                        Curves.Add(new Curve(CurveKind.Line, A, ControlPointA, ControlPointB, B));



                }
                else
                    Curves.Add(new Curve(CurveKind.Line, A, ControlPointA, ControlPointB, B));



            }
            else
                Curves.Add(new Curve(CurveKind.Bezier, A, ControlPointA, ControlPointB, B));

        }
        static void PathList_to_ListOfCurveArrays(ArrayList plistp, ArrayList ListOfCurveArrays)
        {
            ArrayList plist;

            /* call downstream function with each path */
            for (int j = 0; j < plistp.Count; j++)
            {
                plist = (ArrayList)plistp[j];
                ArrayList clist = new ArrayList();
                ListOfCurveArrays.Add(clist);

                for (int i = 0; i < plist.Count; i++)
                {
                    Path p = (Path)plist[i];
                    dPoint A = p.Curves.ControlPoints[p.Curves.n - 1, 2];
                    ArrayList Curves = new ArrayList();
                    for (int k = 0; k < p.Curves.n; k++)
                    {
                        dPoint C = p.Curves.ControlPoints[k, 0];
                        dPoint D = p.Curves.ControlPoints[k, 1];
                        dPoint E = p.Curves.ControlPoints[k, 2];
                        if (p.Curves.tag[k] == POTRACE_CORNER)
                        {
                            AddCurve(Curves, A, A, D, D);
                            AddCurve(Curves, D, D, E, E);

                        }
                        else
                            AddCurve(Curves, A, C, D, E);
                        A = E;
                    }
                    if (Curves.Count > 0)
                    {
                        Curve CL = (Curve)Curves[Curves.Count - 1];
                        Curve CF = (Curve)Curves[0];
                        if ((CL.Kind == CurveKind.Line) && ((CF.Kind == CurveKind.Line))
                            && (iprod(CL.B, CL.A, CF.B) < 0)
                            && (Math.Abs(xprod(new dPoint(CF.B.x - CF.A.x, CF.B.y - CF.A.y), new dPoint(CL.A.x - CL.A.x, CL.B.y - CL.A.y))) < 0.01))
                        {
                            Curves[0] = new Curve(CurveKind.Line, CL.A, CL.A, CL.A, CF.B);
                            Curves.RemoveAt(Curves.Count - 1);
                        }


                        Curve[] CList = new Curve[Curves.Count];
                        for (int ci = 0; ci < Curves.Count; ci++) CList[ci] = (Curve)Curves[ci];
                        clist.Add(CList);
                    }
                }
                //---- Check Last with first



            }

        }

        /// <summary>
        /// Decompose the given bitmap into paths. Returns a linked list of
        /// Path objects with the fields len, pt, area filled
        /// </summary>
        /// <param name="bm">A binary bitmap which holds the imageinformations.</param>
        /// <param name="plistp">List of Path objects</param>
        static void bm_to_pathlist(bool[,] bm, ArrayList plistp)
        {
            int x = 0, y = 0;
            while (FindNext(bm, ref x, ref y))
                getContur(bm, x, y, plistp);
        }


        static void process_path(ArrayList plistp)
        {
            Path p;
            ArrayList plist;
            /* call downstream function with each path */
            for (int j = 0; j < plistp.Count; j++)
            {
                plist = (ArrayList)plistp[j];
                for (int i = 0; i < plist.Count; i++)
                {
                    {
                        p = (Path)plist[i];
                        calc_sums(p);
                        calc_lon(p);
                        bestpolygon(p);
                        adjust_vertices(p);
                        smooth(p.Curves, 1, alphamax);
                        if (curveoptimizing)
                        {
                            opticurve(p, opttolerance);
                            p.FCurves = p.OptimizedCurves;
                        }
                        else
                        {
                            p.FCurves = p.Curves;
                        }
                        p.Curves = p.FCurves;
                    }

                }
            }

        }


        #endregion
    }
}
