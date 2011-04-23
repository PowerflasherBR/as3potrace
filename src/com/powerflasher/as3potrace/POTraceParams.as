package com.powerflasher.as3potrace
{
	public class POTraceParams
	{
		// Area of largest path to be ignored
		public var turdSize:int = 2;
		
		// Corner threshold
		public var alphaMax:Number = 1;
		
		// Use curve optimization
		// Replace sequences of Bezier segments by a single segment when possible.
		public var curveOptimizing:Boolean = true;
		
		// Curve optimizing tolerance
		public var optTolerance:Number = 0.2;
	}
}
