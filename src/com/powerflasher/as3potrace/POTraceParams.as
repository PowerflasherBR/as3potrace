package com.powerflasher.as3potrace
{
	public class POTraceParams
	{
		// For a detailed description of all parameters, see:
		// http://potrace.sourceforge.net/potracelib.pdf
		
		// Note that differing from the original, the
		// curveOptimizing parameter is set to false here.
		
		public function POTraceParams(threshold:uint = 0x888888, thresholdOperator:String = "<=", turdSize:int = 2, alphaMax:Number = 1, curveOptimizing:Boolean = false, optTolerance:Number = 0.2)
		{
			this.threshold = threshold;
			this.thresholdOperator = thresholdOperator;
			this.turdSize = turdSize;
			this.alphaMax = alphaMax;
			this.curveOptimizing = curveOptimizing;
			this.optTolerance = optTolerance;
 		}
 		
		// Value for threshold filter applied to bitmap before processing
		public var threshold:uint;
		
		// The operator to use when the threshold is applied (ex. "<=", ">", etc)
		public var thresholdOperator:String;
		
		// Area of largest path to be ignored
		public var turdSize:int;
		
		// Corner threshold
		public var alphaMax:Number;
		
		// Use curve optimization
		// Replace sequences of Bezier segments by a single segment when possible.
		public var curveOptimizing:Boolean;
		
		// Curve optimizing tolerance
		public var optTolerance:Number;
	}
}
