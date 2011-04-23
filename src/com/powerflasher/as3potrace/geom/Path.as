package com.powerflasher.as3potrace.geom
{
	public class Path
	{
		public var area:int;
		public var monotonIntervals:Vector.<MonotonInterval>;
		public var pt:Vector.<PointInt>;
		public var lon:Vector.<int>;
		public var sums:Vector.<SumStruct>;
		public var po:Vector.<int>;
		public var curves:PrivCurve;
		public var optimizedCurves:PrivCurve;
		public var fCurves:PrivCurve;
		
		public function toString(indent:uint = 0):String
		{
			var si:String = new Array(indent).join(" ");
			var ret:String = si + "[Path area:" + area + "]\n";
			//var i:int;
			ret += si + "  pt (" + pt.length + "):\n";
			ret += si + "    " + pt.join(", ") + "\n";
			ret += si + "  monotonIntervals:\n";
			ret += si + "    " + monotonIntervals.join(", ") + "\n";
			if(sums) {
				ret += si + "  sums:\n";
				ret += si + "    " + sums.join(", ") + "\n";
			}
			if(lon) {
				ret += si + "  lon:\n";
				ret += si + "    " + lon.join(", ") + "\n";
			}
			if(po) {
				ret += si + "  po:\n";
				ret += si + "    " + po.join(", ") + "";
			}
			//for (i = 0; i < pt.length; i++) {
			//	ret += " " + pt[i];
			//}
			return ret;
		}
	}
}
