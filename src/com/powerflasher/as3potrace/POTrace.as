package com.powerflasher.as3potrace
{
	import com.powerflasher.as3potrace.geom.Direction;
	import com.powerflasher.as3potrace.geom.MonotonInterval;
	import com.powerflasher.as3potrace.geom.Path;
	import com.powerflasher.as3potrace.geom.PointInt;

	import flash.display.BitmapData;
	
	public class POTrace
	{
		protected var bmWidth:uint;
		protected var bmHeight:uint;
		
		public function POTrace()
		{
		}
		
		/*
		 * Main function
		 * Yields the curve informations related to a given binary bitmap.
		 * Returns an array of curvepaths. 
		 * Each of this paths is a list of connecting curves.
		 */
		public function potrace_trace(bitmapData:BitmapData):Array
		{
			bmWidth = bitmapData.width;
			bmHeight = bitmapData.height;
			
			var pos:uint = 0;
			var bitmapDataVecTmp:Vector.<uint> = bitmapData.getVector(bitmapData.rect);
			var bitmapDataMatrix:Vector.<Vector.<uint>> = new Vector.<Vector.<uint>>(bmHeight);
			for (var i:int = 0; i < bmHeight; i++) {
				var row:Vector.<uint> = bitmapDataVecTmp.slice(pos, pos + bmWidth);
				for (var j:int = 0; j < row.length; j++) {
					row[j] &= 0xffffff;
				}
				bitmapDataMatrix[i] = row;
				pos += bmWidth;
			}

			var plist:Array;
			plist = bm_to_pathlist(bitmapDataMatrix);
			plist = processPath(plist);
			return PathList_to_ListOfCurveArrays(plist);
		}
		
		/*
		 * Decompose the given bitmap into paths. Returns a linked list of
		 * Path objects with the fields len, pt, area filled
		 */
		private function bm_to_pathlist(bitmapDataMatrix:Vector.<Vector.<uint>>):Array
		{
			var plist:Array;
			var pt:PointInt;
            while ((pt = find_next(bitmapDataMatrix)) != null) {
                get_contur(bitmapDataMatrix, pt, plist);
                break;
            }
            return plist;
		}

		/*
		 * Searches a point such that source[x, y] = true and source[x+1, y] = false.
		 * If this not exists, null will be returned, else the result is Point(x, y).
		 */
		private function find_next(bitmapDataMatrix:Vector.<Vector.<uint>>):PointInt
		{
			var x:int;
			var y:int;
			for (y = 1; y < bmHeight - 1; y++) {
				for (x = 0; x < bmWidth - 1; x++) {
					if(bitmapDataMatrix[y][x + 1] == 0) {
						// Black found
						return new PointInt(x, y);
					}
				}
			}
			return null;
		}

		private function get_contur(bitmapDataMatrix:Vector.<Vector.<uint>>, pt:PointInt, plist:Array):void
		{
			var contur:Path = find_path(bitmapDataMatrix, pt);
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
		private function find_path(bitmapDataMatrix:Vector.<Vector.<uint>>, start:PointInt):Path
		{
			var l:Vector.<PointInt> = new Vector.<PointInt>();
			var p:PointInt = start.clone();
			var dir:uint = Direction.NORTH;
			var area:int = 0;

			do
			{
				l.push(p.clone());
                var _y:int = p.y;
                dir = find_next_trace(bitmapDataMatrix, p, dir);
                area += p.x * (_y - p.y);
            }
            while ((p.x != start.x) || (p.y != start.y));
			
			if(l.length == 0) {
				return null;
			}
			
			var result:Path = new Path();
			result.area = area;
			result.pt = new Vector.<PointInt>(l.length);
			for (var i:int = 0; i < l.length; i++) {
				result.pt[i] = l[i];
			}
			
			// Shift 1 to be compatible with Potrace
			result.pt.unshift(result.pt.pop());
			
			result.monotonIntervals = get_monoton_intervals(result.pt);
			
			return result;
		}

		private function get_monoton_intervals(pt:Vector.<PointInt>):Array
		{
			var result:Array = [];
			var n:uint = pt.length;
			if(n == 0) {
				return result;
			}
			
			var intervals:Vector.<MonotonInterval> = new Vector.<MonotonInterval>();
			
			// Start with Strong Monoton (Pts[i].y < Pts[i+1].y) or (Pts[i].y > Pts[i+1].y)
			var firstStrongMonoton:int = 0;
			while(pt[firstStrongMonoton].y == pt[firstStrongMonoton + 1].y) {
				firstStrongMonoton++;
			}

			var i:int = firstStrongMonoton;
			var up:Boolean = (pt[firstStrongMonoton].y < pt[firstStrongMonoton + 1].y);
			var interval:MonotonInterval = new MonotonInterval(up, firstStrongMonoton, firstStrongMonoton);
			intervals.push(interval);
			
			do
			{
				var i1n:int = (i + 1) % n; 
				if ((pt[i].y == pt[i1n].y) || (up == (pt[i].y < pt[i1n].y))) {
					interval.to = i;
				} else {
					up = (pt[i].y < pt[i1n].y);
					interval = new MonotonInterval(up, i, i);
					intervals.push(interval);
				}
				i = i1n;
			}
			while(i != firstStrongMonoton);
			
			if (intervals.length / 2 * 2 != intervals.length) {
				var last:MonotonInterval = intervals.pop();
				intervals[0].from = last.from;
			}
			
			while(intervals.length > 0)
			{
				i = 0;
				var m:MonotonInterval = intervals.shift();
				while((i < result.length) && (pt[m.min()].y > pt[MonotonInterval(result[i]).min()].y)) {
					i++;
				}
				while((i < result.length) && (pt[m.min()].y == pt[MonotonInterval(result[i]).min()].y) && (pt[m.min()].x > pt[MonotonInterval(result[i]).min()].x)) {
					i++;
				}
				result.splice(i, 0, m);
			}
			
			return result;
		}

		private function find_next_trace(bitmapDataMatrix:Vector.<Vector.<uint>>, p:PointInt, dir:uint):uint
		{
			switch(dir)
			{
				case Direction.WEST:
					if(bitmapDataMatrix[p.y + 1][p.x + 1] == 0) {
						dir = Direction.NORTH;
						p.y++;
					} else {
						if(bitmapDataMatrix[p.y][p.x + 1] == 0) {
							dir = Direction.WEST;
							p.x++;
						} else {
							dir = Direction.SOUTH;
							p.y--;
						}
					}
					break;
					
				case Direction.SOUTH:
					if(bitmapDataMatrix[p.y][p.x + 1] == 0) {
						dir = Direction.WEST;
						p.x++;
					} else {
						if(bitmapDataMatrix[p.y][p.x] == 0) {
							dir = Direction.SOUTH;
							p.y--;
						} else {
							dir = Direction.EAST;
							p.x--;
						}
					}
					break;
					
				case Direction.EAST:
					if(bitmapDataMatrix[p.y][p.x] == 0) {
						dir = Direction.SOUTH;
						p.y--;
					} else {
						if(bitmapDataMatrix[p.y + 1][p.x] == 0) {
							dir = Direction.EAST;
							p.x--;
						} else {
							dir = Direction.NORTH;
							p.y++;
						}
					}
					break;
					
				case Direction.NORTH:
					if(bitmapDataMatrix[p.y + 1][p.x] == 0) {
						dir = Direction.EAST;
						p.x--;
					} else {
						if(bitmapDataMatrix[p.y + 1][p.x + 1] == 0) {
							dir = Direction.NORTH;
							p.y++;
						} else {
							dir = Direction.WEST;
							p.x++;
						}
					}
					break;
			}
			return dir;
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
