package com.powerflasher.as3potrace.geom
{
	import flash.geom.Point;
	
	public class Opti
	{
		public var pen:Number;
		public var c:Vector.<Point>;
		public var t:Number;
		public var s:Number;
		public var alpha:Number;
		
		public function clone():Opti
		{
			var o:Opti = new Opti();
			o.pen = pen;
			o.c = new Vector.<Point>(2);
			o.c[0] = c[0].clone();
			o.c[1] = c[1].clone();
			o.t = t;
			o.s = s;
			o.alpha = alpha;
			return o;
		}
	}
}
