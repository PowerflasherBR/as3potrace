package com.powerflasher.as3potrace.backend
{
	import flash.geom.Point;

	public class NullBackend implements IBackend
	{
		public function init(width:int, height:int):void
		{
		}

		public function moveTo(a:Point):void
		{
		}

		public function addBezier(a:Point, cpa:Point, cpb:Point, b:Point):void
		{
		}

		public function addLine(a:Point, b:Point):void
		{
		}

		public function exit():void
		{
		}
	}
}
