package com.powerflasher.as3potrace.geom
{
	public class PrivCurve
	{
		public var n:int; // Number of segments
		public var tag:Array; // (of int) tag[n] = POTRACE_CORNER or POTRACE_CURVETO
		public var controlPoints:Array; // (of Array of Point) c[n][i]: control points. c[n][0] is unused for tag[n] = POTRACE_CORNER 
		public var vertex:Array; // (of Point) for POTRACE_CORNER, this equals c[1].
		
		public var alpha:Array; // (of Number) only for POTRACE_CURVETO
		public var alpha0:Array; // (of Number) "uncropped" alpha parameter - for debug output only
		public var beta:Array; // (of Number)

		public function PrivCurve(count:int)
		{
			tag = [];
			controlPoints = [];
			vertex = [];
			alpha = [];
			alpha0 = [];
			beta = [];

			n = count;
			for (var i:int = 0; i < n; i++) {
				controlPoints.push([]);
			} 
		}
	}
}
