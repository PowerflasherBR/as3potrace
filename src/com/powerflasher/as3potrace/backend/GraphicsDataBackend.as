package com.powerflasher.as3potrace.backend
{
	import com.powerflasher.as3potrace.geom.CubicCurve;
	import flash.display.GraphicsPath;
	import flash.display.IGraphicsData;
	import flash.geom.Point;

	public class GraphicsDataBackend implements IBackend
	{
		protected var gd:Vector.<IGraphicsData>;
		protected var gp:GraphicsPath;
		
		public function GraphicsDataBackend(gd:Vector.<IGraphicsData>)
		{
			this.gd = gd;
			this.gp = new GraphicsPath();
		}
		
		public function init(width:int, height:int):void
		{
		}

		public function moveTo(a:Point):void
		{
			gp.moveTo(a.x, a.y);
		}

		public function addBezier(a:Point, cpa:Point, cpb:Point, b:Point):void
		{
			trace("  Bezier a:" + a + ", cpa:" + cpa + ", cpb:" + cpb + ", b:" + b);
			var cubic:CubicCurve = new CubicCurve(gp);
			cubic.drawBezierPts(a, cpa, cpb, b);
			gp.lineTo(b.x, b.y);
		}

		public function addLine(a:Point, b:Point):void
		{
			trace("  Line a:" + a + ", b:" + b);
			gp.lineTo(b.x, b.y);
		}

		public function exit():void
		{
			gd.push(gp);
		}
	}
}
