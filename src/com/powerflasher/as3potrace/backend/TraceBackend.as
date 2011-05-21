package com.powerflasher.as3potrace.backend
{
	import com.powerflasher.as3potrace.backend.IBackend;

	import flash.geom.Point;

	public class TraceBackend implements IBackend
	{
		public function init(width:int, height:int):void
		{
			trace("Canvas width:" + width + ", height:" + height);
		}

		public function initShape():void
		{
			trace("  Shape");
		}
		
		public function initSubShape(positive:Boolean):void
		{
			trace("    SubShape positive:" + positive);
		}
		
		public function moveTo(a:Point):void
		{
			trace("      MoveTo a:" + a);
		}

		public function addBezier(a:Point, cpa:Point, cpb:Point, b:Point):void
		{
			trace("      Bezier a:" + a + ", cpa:" + cpa + ", cpb:" + cpb + ", b:" + b);
		}

		public function addLine(a:Point, b:Point):void
		{
			trace("      Line a:" + a + ", b:" + b);
		}

		public function exitSubShape():void
		{
		}
		
		public function exitShape():void
		{
		}
		
		public function exit():void
		{
		}
	}
}
