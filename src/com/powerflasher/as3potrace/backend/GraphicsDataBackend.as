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
		
		protected var lineCount:uint;
		protected var bezierCount:uint;
		
		public function GraphicsDataBackend(gd:Vector.<IGraphicsData>)
		{
			this.gd = gd;
			this.gp = new GraphicsPath();
		}
		
		public function init(width:int, height:int):void
		{
			lineCount = 0;
			bezierCount = 0;
		}

		public function moveTo(a:Point):void
		{
			gp.moveTo(a.x, a.y);
		}

		public function addBezier(a:Point, cpa:Point, cpb:Point, b:Point):void
		{
			var cubic:CubicCurve = new CubicCurve();
			cubic.drawBezierPts(a, cpa, cpb, b);
			for (var i:int = 0; i < cubic.result.length; i++) {
				var quad:Vector.<Point> = cubic.result[i];
				gp.curveTo(quad[1].x, quad[1].y, quad[2].x, quad[2].y);
			}
			bezierCount++;
		}

		public function addLine(a:Point, b:Point):void
		{
			gp.lineTo(b.x, b.y);
			lineCount++;
		}

		public function exit():void
		{
			gd.push(gp);
			trace(bezierCount + " Beziers");
			trace(lineCount + " Lines");
		}
	}
}
