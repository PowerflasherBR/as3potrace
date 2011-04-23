package com.powerflasher.as3potrace.geom
{
	public class MonotonInterval
	{
		public var increasing:Boolean;
		public var from:int;
		public var to:int;
		
		public var currentId:int;
		
		public function MonotonInterval(increasing:Boolean, from:int, to:int)
		{
			this.increasing = increasing;
			this.from = from;
			this.to = to;
		}
		
		public function resetCurrentId(modulo:int):void
		{
			if(!increasing) {
				currentId = mod(min() + 1, modulo);
			} else {
				currentId = min();
			}
		}

		public function min():int
		{
			return increasing ? from : to;
		}

		public function max():int
		{
			return increasing ? to : from;
		}

		public function minY(pts:Vector.<PointInt>):int
		{
			return pts[min()].y;
		}

		public function maxY(pts:Vector.<PointInt>):int
		{
			return pts[max()].y;
		}
		
		private function mod(a:int, n:int):int
		{
			return (a >= n) ? a % n : ((a >= 0) ? a : n - 1 - (-1 - a) % n);
		}
		
		public function toString():String
		{
			return "(" + from + "-" + to + ":" + increasing + ")";
		}
	}
}
