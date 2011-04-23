package com.powerflasher.as3potrace.geom
{
	public class PointInt
	{
		public var x:int;
		public var y:int;
		
		public function PointInt(x:int = 0, y:int = 0)
		{
			this.x = x;
			this.y = y;
		}
		
		public function clone():PointInt
		{
			return new PointInt(x, y);
		}
		
		public function toString():String
		{
			return "(" + x + "," + y + ")";
		}
	}
}
