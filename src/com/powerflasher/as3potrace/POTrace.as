package com.powerflasher.as3potrace
{
	import com.powerflasher.as3potrace.geom.Direction;
	import com.powerflasher.as3potrace.geom.MonotonInterval;
	import com.powerflasher.as3potrace.geom.Path;
	import com.powerflasher.as3potrace.geom.PointInt;
	import com.powerflasher.as3potrace.geom.SumStruct;

	import flash.display.BitmapData;
	
	public class POTrace
	{
		protected var bmWidth:uint;
		protected var bmHeight:uint;
		protected var params:POTraceParams;
		
		public function POTrace()
		{
		}
		
		/*
		 * Main function
		 * Yields the curve informations related to a given binary bitmap.
		 * Returns an array of curvepaths. 
		 * Each of this paths is a list of connecting curves.
		 */
		public function potrace_trace(bitmapData:BitmapData, params:POTraceParams = null):Array
		{
			this.bmWidth = bitmapData.width;
			this.bmHeight = bitmapData.height;
			this.params = (params != null) ? params : new POTraceParams();
			
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
			plist = process_path(plist);
			return PathList_to_ListOfCurveArrays(plist);
		}
		
		/*
		 * Decompose the given bitmap into paths. Returns a linked list of
		 * Path objects with the fields len, pt, area filled
		 */
		private function bm_to_pathlist(bitmapDataMatrix:Vector.<Vector.<uint>>):Array
		{
			var plist:Array = [];
			var pt:PointInt;
            while ((pt = find_next(bitmapDataMatrix)) != null) {
                get_contour(bitmapDataMatrix, pt, plist);
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
					if (bitmapDataMatrix[y][x + 1] == 0) {
						// Black found
						return new PointInt(x, y);
					}
				}
			}
			return null;
		}

		/*
		 * Searches a point inside a path such that source[x, y] = true and source[x+1, y] = false.
		 * If this not exists, null will be returned, else the result is Point(x, y).
		 */
		private function find_next_in_path(bitmapDataMatrix:Vector.<Vector.<uint>>, path:Path):PointInt
		{
			if (path.monotonIntervals.length == 0) {
				return null;
			}
			
			var i:int = 0;
			var n:int = path.pt.length;

			var mis:Array = path.monotonIntervals;
			var mi:MonotonInterval = mis[0] as MonotonInterval;
			mi.resetCurrentId(n);
			
			var y:int = path.pt[mi.currentId].y;
			var currentIntervals:Array = [mi];

			mi.currentId = mi.min();

			while ((mis.length > i + 1) && (MonotonInterval(mis[i + 1]).minY(path.pt) == y))
			{
				mi = MonotonInterval(mis[i + 1]);
				mi.resetCurrentId(n);
				currentIntervals.push(mi);
				i++;
			}
			
			while (currentIntervals.length > 0)
			{
				var j:int;
				
				for (var k:int = 0; k < currentIntervals.length - 1; k++)
				{
					var x1:int = path.pt[MonotonInterval(currentIntervals[k]).currentId].x + 1;
					var x2:int = path.pt[MonotonInterval(currentIntervals[k + 1]).currentId].x;
					for (var x:int = x1; x <= x2; x++) {
						// This is the only difference to xor_path()
						// TODO: Maybe it would be a good idea to merge these two methods?
						if (bitmapDataMatrix[y][x] == 0) {
							return new PointInt(x - 1, y);
						}
					}
					k++;
				}
				
				y++;
				for (j = currentIntervals.length - 1; j >= 0; j--)
				{
					var m:MonotonInterval = MonotonInterval(currentIntervals[j]);
					if (y > m.maxY(path.pt)) {
						currentIntervals.splice(j, 1);
						continue;
					}
					var cid:int = m.currentId;
					do
					{
						cid = m.increasing ? mod(cid + 1, n) : mod(cid - 1, n);
					}
					while (path.pt[cid].y < y);
					m.currentId = cid;
				}
				
				// Add Items of MonotonIntervals with Down.y==y
				while ((mis.length > i + 1) && (MonotonInterval(mis[i + 1]).minY(path.pt) == y))
                {
					var newInt:MonotonInterval = MonotonInterval(mis[i + 1]);
					// Search the correct x position
					j = 0;
					var _x:int = path.pt[newInt.min()].x;
					while ((currentIntervals.length > j) && (_x > path.pt[MonotonInterval(currentIntervals[j]).currentId].x)) {
						j++;
					}
					currentIntervals.splice(j, 0, newInt);
					newInt.resetCurrentId(n);
					i++;
                }
			}
			return null;
		}

		private function get_contour(bitmapDataMatrix:Vector.<Vector.<uint>>, pt:PointInt, plist:Array):void
		{
			var polyPath:Array = [];
			
			//dump_bitmap(bitmapDataMatrix);
			//trace(pt);
			
			var contour:Path = find_path(bitmapDataMatrix, pt);
			xor_path(bitmapDataMatrix, contour);

			// Only area > turdsize is taken
			if (contour.area > params.turdSize) {
				// Path with index 0 is a contour
				polyPath.push(contour);
				plist.push(polyPath);
			}
			
			while ((pt = find_next_in_path(bitmapDataMatrix, contour)) != null)
			{
				//dump_bitmap(bitmapDataMatrix);
				//trace(pt);
				
				var hole:Path = find_path(bitmapDataMatrix, pt);
				xor_path(bitmapDataMatrix, hole);
				
				if (hole.area > params.turdSize) {
					// Path with index > 0 is a hole
					polyPath.push(hole);
				}
				
				if ((pt = find_next_in_path(bitmapDataMatrix, hole)) != null) {
					get_contour(bitmapDataMatrix, pt, plist);
				}
			}
		}

		private function xor_path(bitmapDataMatrix:Vector.<Vector.<uint>>, path:Path):void
		{
			if (path.monotonIntervals.length == 0) {
				return;
			}
			
			var i:int = 0;
			var n:int = path.pt.length;

			var mis:Array = path.monotonIntervals;
			var mi:MonotonInterval = mis[0] as MonotonInterval;
			mi.resetCurrentId(n);
			
			var y:int = path.pt[mi.currentId].y;
			var currentIntervals:Array = [mi];

			mi.currentId = mi.min();

			while ((mis.length > i + 1) && (MonotonInterval(mis[i + 1]).minY(path.pt) == y))
			{
				mi = MonotonInterval(mis[i + 1]);
				mi.resetCurrentId(n);
				currentIntervals.push(mi);
				i++;
			}
			
			while (currentIntervals.length > 0)
			{
				var j:int;
				
				for (var k:int = 0; k < currentIntervals.length - 1; k++)
				{
					var x1:int = path.pt[MonotonInterval(currentIntervals[k]).currentId].x + 1;
					var x2:int = path.pt[MonotonInterval(currentIntervals[k + 1]).currentId].x;
					for (var x:int = x1; x <= x2; x++) {
						// Invert pixel
						bitmapDataMatrix[y][x] ^= 0xffffff;
					}
					k++;
				}
				
				y++;
				for (j = currentIntervals.length - 1; j >= 0; j--)
				{
					var m:MonotonInterval = MonotonInterval(currentIntervals[j]);
					if (y > m.maxY(path.pt)) {
						currentIntervals.splice(j, 1);
						continue;
					}
					var cid:int = m.currentId;
					do
					{
						cid = m.increasing ? mod(cid + 1, n) : mod(cid - 1, n);
					}
					while (path.pt[cid].y < y);
					m.currentId = cid;
				}
				
				// Add Items of MonotonIntervals with Down.y==y
				while ((mis.length > i + 1) && (MonotonInterval(mis[i + 1]).minY(path.pt) == y))
                {
					var newInt:MonotonInterval = MonotonInterval(mis[i + 1]);
					// Search the correct x position
					j = 0;
					var _x:int = path.pt[newInt.min()].x;
					while ((currentIntervals.length > j) && (_x > path.pt[MonotonInterval(currentIntervals[j]).currentId].x)) {
						j++;
					}
					currentIntervals.splice(j, 0, newInt);
					newInt.resetCurrentId(n);
					i++;
                }
			}
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
			
			if (l.length == 0) {
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
			if (n == 0) {
				return result;
			}
			
			var intervals:Vector.<MonotonInterval> = new Vector.<MonotonInterval>();
			
			// Start with Strong Monoton (Pts[i].y < Pts[i+1].y) or (Pts[i].y > Pts[i+1].y)
			var firstStrongMonoton:int = 0;
			while (pt[firstStrongMonoton].y == pt[firstStrongMonoton + 1].y) {
				firstStrongMonoton++;
			}

			var i:int = firstStrongMonoton;
			var up:Boolean = (pt[firstStrongMonoton].y < pt[firstStrongMonoton + 1].y);
			var interval:MonotonInterval = new MonotonInterval(up, firstStrongMonoton, firstStrongMonoton);
			intervals.push(interval);
			
			do
			{
				var i1n:int = mod(i + 1, n); 
				if ((pt[i].y == pt[i1n].y) || (up == (pt[i].y < pt[i1n].y))) {
					interval.to = i;
				} else {
					up = (pt[i].y < pt[i1n].y);
					interval = new MonotonInterval(up, i, i);
					intervals.push(interval);
				}
				i = i1n;
			}
			while (i != firstStrongMonoton);
			
			if (intervals.length / 2 * 2 != intervals.length) {
				var last:MonotonInterval = intervals.pop();
				intervals[0].from = last.from;
			}
			
			while (intervals.length > 0)
			{
				i = 0;
				var m:MonotonInterval = intervals.shift();
				while ((i < result.length) && (pt[m.min()].y > pt[MonotonInterval(result[i]).min()].y)) {
					i++;
				}
				while ((i < result.length) && (pt[m.min()].y == pt[MonotonInterval(result[i]).min()].y) && (pt[m.min()].x > pt[MonotonInterval(result[i]).min()].x)) {
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
					if (bitmapDataMatrix[p.y + 1][p.x + 1] == 0) {
						dir = Direction.NORTH;
						p.y++;
					} else {
						if (bitmapDataMatrix[p.y][p.x + 1] == 0) {
							dir = Direction.WEST;
							p.x++;
						} else {
							dir = Direction.SOUTH;
							p.y--;
						}
					}
					break;
					
				case Direction.SOUTH:
					if (bitmapDataMatrix[p.y][p.x + 1] == 0) {
						dir = Direction.WEST;
						p.x++;
					} else {
						if (bitmapDataMatrix[p.y][p.x] == 0) {
							dir = Direction.SOUTH;
							p.y--;
						} else {
							dir = Direction.EAST;
							p.x--;
						}
					}
					break;
					
				case Direction.EAST:
					if (bitmapDataMatrix[p.y][p.x] == 0) {
						dir = Direction.SOUTH;
						p.y--;
					} else {
						if (bitmapDataMatrix[p.y + 1][p.x] == 0) {
							dir = Direction.EAST;
							p.x--;
						} else {
							dir = Direction.NORTH;
							p.y++;
						}
					}
					break;
					
				case Direction.NORTH:
					if (bitmapDataMatrix[p.y + 1][p.x] == 0) {
						dir = Direction.EAST;
						p.x--;
					} else {
						if (bitmapDataMatrix[p.y + 1][p.x + 1] == 0) {
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

		private function process_path(plists:Array):Array
		{
			// call downstream function with each path
			for (var j:int = 0; j < plists.length; j++) {
				var plist:Array = plists[j] as Array;
				for (var i:int = 0; i < plist.length; i++) {
					var path:Path = plist[i] as Path;
					calc_sums(path);
					calc_lon(path);
					bestpolygon(path);
					//adjust_vertices(path);
				}
			}
			return null;
		}

		private function adjust_vertices(path:Path):void
		{
		}

		/*
		 * Preparation: fill in the sum* fields of a path
		 * (used for later rapid summing)
		 */
		private function calc_sums(path:Path):void
		{
			var ss:SumStruct;
			var n:int = path.pt.length;
			
			// Origin
			var x0:int = path.pt[0].x;
			var y0:int = path.pt[0].y;
			
			path.sums = new Vector.<SumStruct>(n + 1);
			
			ss = new SumStruct();
			ss.x2 = ss.xy = ss.y2 = ss.x = ss.y = 0;
			path.sums[0] = ss;
			
			for (var i:int = 0; i < n; i++) {
				var x:int = path.pt[i].x - x0;
				var y:int = path.pt[i].y - y0;
				ss = new SumStruct();
				ss.x = path.sums[i].x + x; 
				ss.y = path.sums[i].y + y; 
				ss.x2 = path.sums[i].x2 + x * x; 
				ss.xy = path.sums[i].xy + x * y; 
				ss.y2 = path.sums[i].y2 + y * y; 
				path.sums[i + 1] = ss;
			}
		}

		private function calc_lon(path:Path):void
		{
			var i:int;
			var j:int;
			var k:int;
			var k1:int;
			var a:int;
			var b:int;
			var c:int;
			var d:int;
			var dir:int;
			var ct:Vector.<int> = new Vector.<int>(4);
			var constraint:Vector.<PointInt> = new Vector.<PointInt>(2);
			constraint[0] = new PointInt(0, 0);
			constraint[1] = new PointInt(0, 0);
			var cur:PointInt = new PointInt(0, 0);
			var off:PointInt = new PointInt(0, 0);
			var dk:PointInt = new PointInt(0, 0);; // direction of k-k1
			var pt:Vector.<PointInt> = path.pt;
			
			var n:int = pt.length;
			var pivot:Vector.<int> = new Vector.<int>(n);
			var nc:Vector.<int> = new Vector.<int>(n);
			
			// Initialize the nc data structure. Point from each point to the
			// furthest future point to which it is connected by a vertical or
			// horizontal segment. We take advantage of the fact that there is
			// always a direction change at 0 (due to the path decomposition
			// algorithm). But even if this were not so, there is no harm, as
			// in practice, correctness does not depend on the word "furthest"
			// above.
			
			k = 0;
			for (i = n - 1; i >= 0; i--)
			{
				if (pt[i].x != pt[k].x && pt[i].y != pt[k].y) {
					k = i + 1; // necessarily i < n-1 in this case
				}
				nc[i] = k;
			}
			
			path.lon = new Vector.<int>(n);
			
			// Determine pivot points:
			// for each i, let pivk[i] be the furthest k such that 
			// all j with i < j < k lie on a line connecting i,k
			
			for (i = n - 1; i >= 0; i--)
			{
				ct[0] = ct[1] = ct[2] = ct[3] = 0;
				
				// Keep track of "directions" that have occurred
				dir = (3 + 3 * (pt[mod(i + 1, n)].x - pt[i].x) + (pt[mod(i + 1, n)].y - pt[i].y)) / 2;
				ct[dir]++;
				
				constraint[0].x = 0;
				constraint[0].y = 0;
				constraint[1].x = 0;
				constraint[1].y = 0;
				
				// Find the next k such that no straight line from i to k
				k = nc[i];
				k1 = i;
				
				var foundk:Boolean = false;
				while (true)
				{
					dir = (3 + 3 * sign(pt[k].x - pt[k1].x) + sign(pt[k].y - pt[k1].y)) / 2;
					ct[dir]++;
					
					// If all four "directions" have occurred, cut this path
					if ((ct[0] == 1) && (ct[1] == 1) && (ct[2] == 1) && (ct[3] == 1)) {
						pivot[i] = k1;
						foundk = true;
						break;
					}
					
					cur.x = pt[k].x - pt[i].x;
					cur.y = pt[k].y - pt[i].y;
					
					// See if current constraint is violated
					if (xprod(constraint[0], cur) < 0 || xprod(constraint[1], cur) > 0) {
						break;
					}
					
					if (abs(cur.x) <= 1 && abs(cur.y) <= 1) {
						// no constraint
					} else {
						off.x = cur.x + ((cur.y >= 0 && (cur.y > 0 || cur.x < 0)) ? 1 : -1);
						off.y = cur.y + ((cur.x <= 0 && (cur.x < 0 || cur.y < 0)) ? 1 : -1);
						if (xprod(constraint[0], off) >= 0) {
							constraint[0] = off.clone();
						}
						off.x = cur.x + ((cur.y <= 0 && (cur.y < 0 || cur.x < 0)) ? 1 : -1);
						off.y = cur.y + ((cur.x >= 0 && (cur.x > 0 || cur.y < 0)) ? 1 : -1);
						if (xprod(constraint[1], off) <= 0) {
							constraint[1] = off.clone();
						}
					}
					
					k1 = k;
					k = nc[k1];
					if (!cyclic(k, i, k1)) {
						break;
					}
				}
				
				if(foundk) {
					continue;
				}
				
				// k1 was the last "corner" satisfying the current constraint, and
				// k is the first one violating it. We now need to find the last
				// point along k1..k which satisfied the constraint.
				dk.x = sign(pt[k].x - pt[k1].x);
				dk.y = sign(pt[k].y - pt[k1].y);
				cur.x = pt[k1].x - pt[i].x;
				cur.y = pt[k1].y - pt[i].y;
				
				// find largest integer j such that xprod(constraint[0], cur+j*dk)
				// >= 0 and xprod(constraint[1], cur+j*dk) <= 0. Use bilinearity
				// of xprod.
				a = xprod(constraint[0], cur);
				b = xprod(constraint[0], dk);
				c = xprod(constraint[1], cur);
				d = xprod(constraint[1], dk);

				// find largest integer j such that a+j*b>=0 and c+j*d<=0. This
				// can be solved with integer arithmetic.
				j = int.MAX_VALUE;
				if (b < 0) {
				    j = floordiv(a, -b);
				}
				if (d > 0) {
				    j = min(j, floordiv(-c, d));
				}
				pivot[i] = mod(k1 + j, n);
			}
			
			// Clean up:
			// for each i, let lon[i] be the largest k such that
			// for all i' with i <= i' < k, i' < k <= pivk[i']. */
			
			j = pivot[n - 1];
			path.lon[n - 1] = j;
			
			for (i = n - 2; i >= 0; i--) {
				if (cyclic(i + 1, pivot[i], j)) {
					j - pivot[i];
				}
				path.lon[i] = j;
			}
			
			for (i = n - 1; cyclic(mod(i + 1, n), j, path.lon[i]); i--) {
				path.lon[i] = j;
			}
		}

		private function bestpolygon(path:Path):void
		{
			var i:int;
			var j:int;
			var m:int;
			var k:int;
			var n:int = path.pt.length;
			var pen:Vector.<Number> = new Vector.<Number>(n + 1); // penalty vector
			var prev:Vector.<int> = new Vector.<int>(n + 1); // best path pointer vector
			var clip0:Vector.<int> = new Vector.<int>(n); // longest segment pointer, non-cyclic
			var clip1:Vector.<int> = new Vector.<int>(n + 1); // backwards segment pointer, non-cyclic
			var seg0:Vector.<int> = new Vector.<int>(n + 1); // forward segment bounds, m <= n
			var seg1:Vector.<int> = new Vector.<int>(n + 1); // backward segment bounds, m <= n
			
			var thispen:Number;
			var best:Number;
			var c:int;
			
			// Calculate clipped paths
			for (i = 0; i < n; i++) {
				c = mod(path.lon[mod(i - 1, n)] - 1, n);
				if (c == i) {
					c = mod(i + 1, n);
				}
				clip0[i] = (c < i) ? n : c;
			}
			
			// calculate backwards path clipping, non-cyclic. 
			// j <= clip0[i] iff clip1[j] <= i, for i,j = 0..n
			j = 1;
			for (i = 0; i < n; i++) {
			    while (j <= clip0[i]) {
			        clip1[j] = i;
			        j++;
			    }
			}
			
			// calculate seg0[j] = longest path from 0 with j segments
			i = 0;
			for (j = 0; i < n; j++) {
			    seg0[j] = i;
			    i = clip0[i];
			}
			seg0[j] = n;
			
			// calculate seg1[j] = longest path to n with m-j segments
			i = n;
			m = j;
			for (j = m; j > 0; j--) {
			    seg1[j] = i;
			    i = clip1[i];
			}
			seg1[0] = 0;
			
			// Now find the shortest path with m segments, based on penalty3
			// Note: the outer 2 loops jointly have at most n interations, thus
			// the worst-case behavior here is quadratic. In practice, it is
			// close to linear since the inner loop tends to be short.
			pen[0] = 0;
			for (j = 1; j <= m; j++) {
				for (i = seg1[j]; i <= seg0[j]; i++) {
					best = -1;
					for (k = seg0[j - 1]; k >= clip1[i]; k--) {
						thispen = penalty3(path, k, i) + pen[k];
						if (best < 0 || thispen < best) {
							prev[i] = k;
							best = thispen;
						}
					}
					pen[i] = best;
				}
			}
			
			// read off shortest path
			path.po = new Vector.<int>(m);
			for (i = n, j = m - 1; i > 0; j--) {
				i = path.po[j] = prev[i];
			}
		}

		/* 
		 * Auxiliary function: calculate the penalty of an edge from i to j in
		 * the given path. This needs the "lon" and "sum*" data.
		 */
		private function penalty3(path:Path, i:int, j:int):Number
		{
			var n:int = path.pt.length;
			
			// assume 0 <= i < j <= n
			var sums:Vector.<SumStruct> = path.sums;
			var pt:Vector.<PointInt> = path.pt;

			var r:int = 0; // rotations from i to j
			if (j >= n) {
				j -= n;
				r++;
		    }

			var x:Number = sums[j + 1].x - sums[i].x + r * sums[n].x;
			var y:Number = sums[j + 1].y - sums[i].y + r * sums[n].y;
			var x2:Number = sums[j + 1].x2 - sums[i].x2 + r * sums[n].x2;
			var xy:Number = sums[j + 1].xy - sums[i].xy + r * sums[n].xy;
			var y2:Number = sums[j + 1].y2 - sums[i].y2 + r * sums[n].y2;
			var k:Number = j + 1 - i + r * n;

			var px:Number = (pt[i].x + pt[j].x) / 2.0 - pt[0].x;
			var py:Number = (pt[i].y + pt[j].y) / 2.0 - pt[0].y;
			var ey:Number = (pt[j].x - pt[i].x);
			var ex:Number = -(pt[j].y - pt[i].y);

			var a:Number = ((x2 - 2 * x * px) / k + px * px);
			var b:Number = ((xy - x * py - y * px) / k + px * py);
			var c:Number = ((y2 - 2 * y * py) / k + py * py);

		    return Math.sqrt(ex * ex * a + 2 * ex * ey * b + ey * ey * c);
		}

		private function PathList_to_ListOfCurveArrays(plist:Array):Array
		{
			return null;
		}
		
		private function dump_bitmap(bitmapDataMatrix:Vector.<Vector.<uint>>):void
		{
			for (var y:int = 0; y < bitmapDataMatrix.length; y++) {
				var row:String = "";
				for (var x:int = 0; x < bitmapDataMatrix[y].length; x++) {
					row += (bitmapDataMatrix[y][x] == 0) ? "x " : ". ";
				}
				trace(row);
			}
		}
		
		private function xprod(p1:PointInt, p2:PointInt):int
		{
			return p1.x * p2.y - p1.y * p2.x;
		}
		
		private function abs(a:int):int
		{
			return (a > 0) ? a : -a;
		}
		
		private function cyclic(a:int, b:int, c:int):Boolean
		{
			if (a <= c) {
				return (a <= b && b < c);
			} else {
				return (a <= b || b < c);
			}
		}
		
		private function floordiv(a:int, n:int):int
		{
			return (a >= 0) ? a / n : -1 - (-1 - a) / n;
		}
		
		private function min(a:int, b:int):int
		{
			return (a < b) ? a : b;
		}
		
		private function max(a:int, b:int):int
		{
			return (a > b) ? a : b;
		}
		
		private function mod(a:int, n:int):int
		{
			return (a >= n) ? a % n : ((a >= 0) ? a : n - 1 - (-1 - a) % n);
		}
		
		private function sign(x:int):int
		{
			return (x > 0) ? 1 : ((x < 0) ? -1 : 0);
		}
	}
}
