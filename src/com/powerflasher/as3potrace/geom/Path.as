package com.powerflasher.as3potrace.geom
{
	public class Path
	{
		public var area:int;
		public var monotonIntervals:Array;
		public var pt:Vector.<PointInt>;
		public var lon:Vector.<int>;
		public var sums:Vector.<SumStruct>;
		public var po:Vector.<int>;
		public var curves:PrivCurve;
		public var optimizedCurves:PrivCurve;
		public var fCurves:PrivCurve;
		
		public function Path()
		{
		}
	}
}
