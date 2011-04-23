package com.powerflasher.as3potrace.geom
{
	import flash.geom.Point;
	
	public class PrivCurve
	{
		public var n:int;
		public var tag:Vector.<int>;
		public var controlPoints:Vector.<Vector.<Point>>; 
		public var vertex:Vector.<Point>;
		public var alpha:Vector.<Number>;
		public var alpha0:Vector.<Number>;
		public var beta:Vector.<Number>;

		public function PrivCurve(count:int)
		{
			// Number of segments
			n = count;

			// tag[n] = POTRACE_CORNER or POTRACE_CURVETO
			tag = new Vector.<int>(n);
			
			// c[n][i]: control points.
			// c[n][0] is unused for tag[n] = POTRACE_CORNER
			controlPoints = new Vector.<Vector.<Point>>(n);
			for (var i:int = 0; i < n; i++) {
				controlPoints[i] = new Vector.<Point>(3);
			}
			
			// for POTRACE_CORNER, this equals c[1].			
			vertex = new Vector.<Point>(n);
			
			// only for POTRACE_CURVETO
			alpha = new Vector.<Number>(n);
			
			// for debug output only
			// "uncropped" alpha parameter
			alpha0 = new Vector.<Number>(n);
			
			beta = new Vector.<Number>(n);
		}
	}
}
