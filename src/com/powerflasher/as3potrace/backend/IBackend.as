package com.powerflasher.as3potrace.backend
{
	import flash.geom.Point;
	
	public interface IBackend
	{
		function init(width:int, height:int):void;
		function moveTo(a:Point):void;
		function addBezier(a:Point, cpa:Point, cpb:Point, b:Point):void;
		function addLine(a:Point, b:Point):void;
		function exit():void;
	}
}
