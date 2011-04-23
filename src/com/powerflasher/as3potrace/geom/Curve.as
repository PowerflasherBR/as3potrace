package com.powerflasher.as3potrace.geom
{
	import flash.geom.Point;
	
	public class Curve
	{
		// Bezier or Line
		public var kind:int;

		// Startpoint
		public var a:Point;

		// ControlPoint
		public var cpa:Point;

		// ControlPoint
		public var cpb:Point;

		// Endpoint
		public var b:Point;
		
		public function Curve(kind:int, a:Point, cpa:Point, cpb:Point, b:Point)
		{
			this.kind = kind;
			this.a = a;
			this.cpa = cpa;
			this.cpb = cpb;
			this.b = b;
		}
	}
}
