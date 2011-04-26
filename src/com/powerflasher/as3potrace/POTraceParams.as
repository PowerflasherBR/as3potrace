package com.powerflasher.as3potrace
{
	public class POTraceParams
	{
		// Value for threshold filter applied to bitmap before processing
		public var threshold:uint = 0x888888;
		
		// The thrshold operator used
		public var thresholdOperator:String = "<=";
		
		// Area of largest path to be ignored
		public var turdSize:int = 2;
		
		// Corner threshold
		public var alphaMax:Number = 1;
		
		// Use curve optimization
		// Replace sequences of Bezier segments by a single segment when possible.
		public var curveOptimizing:Boolean = false;
		
		// Curve optimizing tolerance
		public var optTolerance:Number = 0.2;
	}
}
