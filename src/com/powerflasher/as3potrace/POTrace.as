package com.powerflasher.as3potrace
{
	import com.powerflasher.as3potrace.geom.Direction;
	import com.powerflasher.as3potrace.geom.Path;
	import flash.geom.Point;
	import flash.display.BitmapData;
	
	public class POTrace
	{
		protected var bmd:BitmapData;
		
		public function POTrace()
		{
		}
		
		public function traceBitmap(bitmapData:BitmapData):Array
		{
			var plist:Array = bm_to_pathlist(bitmapData);
	
			plist = processPath(plist);
			
			return PathList_to_ListOfCurveArrays(plist);
		}

		private function bm_to_pathlist(bitmapData:BitmapData):Array
		{
			var pt:Point;
			var plist:Array;
            while ((pt = findNext(bitmapData)) != null) {
                getContur(bitmapData, pt, plist);
                break;
            }
            return plist;
		}

		/*
		 * Searches a point such that source[x, y] = true and source[x+1, y] = false.
		 * If this not exists, null will be returned, else the result is Point(x, y).
		 */
		private function findNext(bitmapData:BitmapData):Point
		{
			var x:int;
			var y:int;
			for (y = 1; y < bitmapData.height - 1; y++) {
				for (x = 0; x < bitmapData.width - 1; x++) {
					if(bitmapData.getPixel(x + 1, y) == 0) {
						// Black found
						return new Point(x, y);
					}
				}
			}
			return null;
		}

		private function getContur(bitmapData:BitmapData, pt:Point, plist:Array):void
		{
			var contur:Path = findPath(bitmapData, pt);
		}

		/*
		 * Compute a path in the binary matrix.
		 * 
		 * Start path at the point (x0,x1), which must be an upper left corner
		 * of the path. Also compute the area enclosed by the path. Return a
		 * new path_t object, or NULL on error (note that a legitimate path
		 * cannot have length 0).
		 * 
		 * We omit turnpolicies and sign
		 */
		private function findPath(bitmapData:BitmapData, start:Point):Path
		{
			var l:Array = [];
			var dir:uint = Direction.NORTH;
			var x:int = start.x;
			var y:int = start.y;
			var area:int = 0;
			var diry:int = -1;

			do
			{
				// area += x * diry;
				l.push(new Point(x, y));
                var _y:int = y;
                findNextTrace(Matrix, ref x, ref y, ref Dir);
                diry = _y - y;
                area += x * diry;
            }
            while ((x != start.x) || (y != start.y));
			
			return null;
		}

		private function processPath(plist:Array):Array
		{
			return null;
		}

		private function PathList_to_ListOfCurveArrays(plist:Array):Array
		{
			return null;
		}
	}
}
