package com.powerflasher.as3potrace
{
	import com.powerflasher.as3potrace.backend.IBackend;
	import com.powerflasher.as3potrace.backend.NullBackend;
	import com.powerflasher.as3potrace.geom.Curve;
	import com.powerflasher.as3potrace.geom.CurveKind;
	import com.powerflasher.as3potrace.geom.Direction;
	import com.powerflasher.as3potrace.geom.MonotonInterval;
	import com.powerflasher.as3potrace.geom.Path;
	import com.powerflasher.as3potrace.geom.PointInt;
	import com.powerflasher.as3potrace.geom.PrivCurve;
	import com.powerflasher.as3potrace.geom.SumStruct;

	import flash.display.BitmapData;
	import flash.geom.Point;
	
	public class POTrace
	{
		protected var bmWidth:uint;
		protected var bmHeight:uint;
		protected var params:POTraceParams;
		
		protected static const POTRACE_CORNER:int = 1;
		protected static const POTRACE_CURVETO:int = 2;
		
		public function POTrace()
		{
		}
		
		/*
		 * Main function
		 * Yields the curve informations related to a given binary bitmap.
		 * Returns an array of curvepaths. 
		 * Each of this paths is a list of connecting curves.
		 */
		public function potrace_trace(bitmapData:BitmapData, params:POTraceParams = null, backend:IBackend = null):Array
		{
			// Make sure there is a 1px white border
			var bitmapDataCopy:BitmapData = new BitmapData(bitmapData.width + 2, bitmapData.height + 2, false, 0xffffff);
			bitmapDataCopy.copyPixels(bitmapData, bitmapData.rect, new Point(1, 1));
			
			this.bmWidth = bitmapDataCopy.width;
			this.bmHeight = bitmapDataCopy.height;
			this.params = (params != null) ? params : new POTraceParams();

			if(backend == null) {
				backend = new NullBackend();
			}
			backend.init(bmWidth, bmHeight);
			
			var i:int;
			var j:int;
			var pos:uint = 0;
			var bitmapDataVecTmp:Vector.<uint> = bitmapDataCopy.getVector(bitmapDataCopy.rect);
			var bitmapDataMatrix:Vector.<Vector.<uint>> = new Vector.<Vector.<uint>>(bmHeight);
			
			for (i = 0; i < bmHeight; i++) {
				var row:Vector.<uint> = bitmapDataVecTmp.slice(pos, pos + bmWidth);
				for (j = 0; j < row.length; j++) {
					row[j] &= 0xffffff;
				}
				bitmapDataMatrix[i] = row;
				pos += bmWidth;
			}

			var plist:Array = bm_to_pathlist(bitmapDataMatrix);
			
			process_path(plist);
			
			var shapes:Array = pathlist_to_curvearrayslist(plist);
			
			for (i = 0; i < shapes.length; i++) {
				var shape:Array = shapes[i] as Array;
				for (j = 0; j < shape.length; j++) {
					var curves:Array = shape[j] as Array;
					if(curves.length > 0) {
						var curve:Curve = curves[0] as Curve;
						backend.moveTo(curve.a.clone());
						for (var k:int = 0; k < curves.length; k++) {
							curve = curves[k] as Curve;
							switch(curve.kind) {
								case CurveKind.BEZIER:
									backend.addBezier(
										curve.a.clone(),
										curve.cpa.clone(),
										curve.cpb.clone(),
										curve.b.clone()
									);
									break;
								case CurveKind.LINE:
									backend.addLine(
										curve.a.clone(),
										curve.b.clone()
									);
									break;
							}
						}
					}
				}
			}
			backend.exit();
			
			return shapes;
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

		private function get_contour(bitmapDataMatrix:Vector.<Vector.<uint>>, pt:PointInt, plists:Array):void
		{
			var plist:Array = [];
			
			//dump_bitmap(bitmapDataMatrix);
			//trace(pt);
			
			var path:Path = find_path(bitmapDataMatrix, pt);
			xor_path(bitmapDataMatrix, path);

			// Only area > turdsize is taken
			if (path.area > params.turdSize) {
				// Path with index 0 is a contour
				plist.push(path);
				plists.push(plist);
			}
			
			while ((pt = find_next_in_path(bitmapDataMatrix, path)) != null)
			{
				//dump_bitmap(bitmapDataMatrix);
				//trace(pt);
				
				var hole:Path = find_path(bitmapDataMatrix, pt);
				xor_path(bitmapDataMatrix, hole);
				
				if (hole.area > params.turdSize) {
					// Path with index > 0 is a hole
					plist.push(hole);
				}
				
				if ((pt = find_next_in_path(bitmapDataMatrix, hole)) != null) {
					get_contour(bitmapDataMatrix, pt, plists);
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
			if(result.pt.length > 1) {
				result.pt.unshift(result.pt.pop());
			}
			
			result.monotonIntervals = get_monoton_intervals(result.pt);
			
			return result;
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

			var mis:Vector.<MonotonInterval> = path.monotonIntervals;
			var mi:MonotonInterval = mis[0];
			mi.resetCurrentId(n);
			
			var y:int = path.pt[mi.currentId].y;

			var currentIntervals:Vector.<MonotonInterval> = new Vector.<MonotonInterval>();
			currentIntervals[0] = mi;

			mi.currentId = mi.min();

			while ((mis.length > i + 1) && (mis[i + 1].minY(path.pt) == y))
			{
				mi = mis[i + 1];
				mi.resetCurrentId(n);
				currentIntervals.push(mi);
				i++;
			}
			
			while (currentIntervals.length > 0)
			{
				var j:int;
				
				for (var k:int = 0; k < currentIntervals.length - 1; k++)
				{
					var x1:int = path.pt[currentIntervals[k].currentId].x + 1;
					var x2:int = path.pt[currentIntervals[k + 1].currentId].x;
					for (var x:int = x1; x <= x2; x++) {
						if (bitmapDataMatrix[y][x] == 0) {
							return new PointInt(x - 1, y);
						}
					}
					k++;
				}
				
				y++;
				for (j = currentIntervals.length - 1; j >= 0; j--)
				{
					var m:MonotonInterval = currentIntervals[j];
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
				while ((mis.length > i + 1) && (mis[i + 1].minY(path.pt) == y))
                {
					var newInt:MonotonInterval = mis[i + 1];
					// Search the correct x position
					j = 0;
					var _x:int = path.pt[newInt.min()].x;
					while ((currentIntervals.length > j) && (_x > path.pt[currentIntervals[j].currentId].x)) {
						j++;
					}
					currentIntervals.splice(j, 0, newInt);
					newInt.resetCurrentId(n);
					i++;
                }
			}
			return null;
		}

		private function xor_path(bitmapDataMatrix:Vector.<Vector.<uint>>, path:Path):void
		{
			if (path.monotonIntervals.length == 0) {
				return;
			}
			
			var i:int = 0;
			var n:int = path.pt.length;

			var mis:Vector.<MonotonInterval> = path.monotonIntervals;
			var mi:MonotonInterval = mis[0];
			mi.resetCurrentId(n);
			
			var y:int = path.pt[mi.currentId].y;
			var currentIntervals:Vector.<MonotonInterval> = new Vector.<MonotonInterval>();
			currentIntervals.push(mi);

			mi.currentId = mi.min();

			while ((mis.length > i + 1) && (mis[i + 1].minY(path.pt) == y))
			{
				mi = mis[i + 1];
				mi.resetCurrentId(n);
				currentIntervals.push(mi);
				i++;
			}
			
			while (currentIntervals.length > 0)
			{
				var j:int;
				
				for (var k:int = 0; k < currentIntervals.length - 1; k++)
				{
					var x1:int = path.pt[currentIntervals[k].currentId].x + 1;
					var x2:int = path.pt[currentIntervals[k + 1].currentId].x;
					for (var x:int = x1; x <= x2; x++) {
						// Invert pixel
						bitmapDataMatrix[y][x] ^= 0xffffff;
					}
					k++;
				}
				
				y++;
				for (j = currentIntervals.length - 1; j >= 0; j--)
				{
					var m:MonotonInterval = currentIntervals[j];
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
				while ((mis.length > i + 1) && (mis[i + 1].minY(path.pt) == y))
                {
					var newInt:MonotonInterval = mis[i + 1];
					// Search the correct x position
					j = 0;
					var _x:int = path.pt[newInt.min()].x;
					while ((currentIntervals.length > j) && (_x > path.pt[currentIntervals[j].currentId].x)) {
						j++;
					}
					currentIntervals.splice(j, 0, newInt);
					newInt.resetCurrentId(n);
					i++;
                }
			}
		}

		private function get_monoton_intervals(pt:Vector.<PointInt>):Vector.<MonotonInterval>
		{
			var result:Vector.<MonotonInterval> = new Vector.<MonotonInterval>();
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
			
			if ((intervals.length & 1) == 1) {
				var last:MonotonInterval = intervals.pop();
				intervals[0].from = last.from;
			}
			
			while (intervals.length > 0)
			{
				i = 0;
				var m:MonotonInterval = intervals.shift();
				while ((i < result.length) && (pt[m.min()].y > pt[result[i].min()].y)) {
					i++;
				}
				while ((i < result.length) && (pt[m.min()].y == pt[result[i].min()].y) && (pt[m.min()].x > pt[result[i].min()].x)) {
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

		private function process_path(plists:Array):void
		{
			// call downstream function with each path
			for (var j:int = 0; j < plists.length; j++) {
				var plist:Array = plists[j] as Array;
				for (var i:int = 0; i < plist.length; i++) {
					var path:Path = plist[i] as Path;
					calc_sums(path);
					calc_lon(path);
					bestpolygon(path);
					adjust_vertices(path);
					smooth(path.curves, 1, params.alphaMax);
				}
			}
		}

		/////////////////////////////////////////////////////////////////////////
		// PREPARATION
		/////////////////////////////////////////////////////////////////////////

		/*
		 * Fill in the sum* fields of a path (used for later rapid summing)
		 */
		private function calc_sums(path:Path):void
		{
			var n:int = path.pt.length;
			
			// Origin
			var x0:int = path.pt[0].x;
			var y0:int = path.pt[0].y;
			
			path.sums = new Vector.<SumStruct>(n + 1);
			
			var ss:SumStruct = new SumStruct();
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

		/////////////////////////////////////////////////////////////////////////
		// STAGE 1
		// determine the straight subpaths (Sec. 2.2.1).
		/////////////////////////////////////////////////////////////////////////

		/*
		 * Fill in the "lon" component of a path object (based on pt/len).
		 * For each i, lon[i] is the furthest index such that a straight line 
		 * can be drawn from i to lon[i].
		 * 
		 * This algorithm depends on the fact that the existence of straight
		 * subpaths is a triplewise property. I.e., there exists a straight
		 * line through squares i0,...,in if there exists a straight line
		 * through i,j,k, for all i0 <= i < j < k <= in. (Proof?)
		 */ 
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
			constraint[0] = new PointInt();
			constraint[1] = new PointInt();
			var cur:PointInt = new PointInt();
			var off:PointInt = new PointInt();
			var dk:PointInt = new PointInt(); // direction of k - k1
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
			// for each i, let pivot[i] be the furthest k such that 
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
					if ((ct[0] >= 1) && (ct[1] >= 1) && (ct[2] >= 1) && (ct[3] >= 1)) {
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

				// find largest integer j such that a+j*b >= 0 and c+j*d <= 0. This
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
					j = pivot[i];
				}
				path.lon[i] = j;
			}
			
			for (i = n - 1; cyclic(mod(i + 1, n), j, path.lon[i]); i--) {
				path.lon[i] = j;
			}
		}

		/////////////////////////////////////////////////////////////////////////
		// STAGE 2
		// Calculate the optimal polygon (Sec. 2.2.2 - 2.2.4).
		/////////////////////////////////////////////////////////////////////////

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

		/*
		 * Find the optimal polygon.
		 */
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
				i = prev[i];
				path.po[j] = i;
			}
		}

		/////////////////////////////////////////////////////////////////////////
		// STAGE 3
		// Vertex adjustment (Sec. 2.3.1).
		/////////////////////////////////////////////////////////////////////////

		/*
		 * Adjust vertices of optimal polygon: calculate the intersection of
		 * the two "optimal" line segments, then move it into the unit square
		 * if it lies outside.
		 */
		private function adjust_vertices(path:Path):void
		{
			var pt:Vector.<PointInt> = path.pt;
			var po:Vector.<int> = path.po;
			
			var n:int = pt.length;
			var m:int = po.length;

			var x0:int = pt[0].x;
			var y0:int = pt[0].y;
			
			var i:int;
			var j:int;
			var k:int;
			var l:int;

			var d:Number;
			var v:Vector.<Number> = new Vector.<Number>(3);
			var q:Vector.<Vector.<Vector.<Number>>> = new Vector.<Vector.<Vector.<Number>>>(m);
			
			var ctr:Vector.<Point> = new Vector.<Point>(m);
			var dir:Vector.<Point> = new Vector.<Point>(m);
			
			for (i = 0; i < m; i++) {
				q[i] = new Vector.<Vector.<Number>>(3);
				for (j = 0; j < 3; j++) {
					q[i][j] = new Vector.<Number>(3);
				}
				ctr[i] = new Point();
				dir[i] = new Point();
			}
			
			var s:Point = new Point();
			
			path.curves = new PrivCurve(m);
			
			// calculate "optimal" point-slope representation for each line segment
			for (i = 0; i < m; i++) {
				j = po[mod(i + 1, m)];
				j = mod(j - po[i], n) + po[i];
				pointslope(path, po[i], j, ctr[i], dir[i]);
			}
			
			// represent each line segment as a singular quadratic form;
			// the distance of a point (x,y) from the line segment will be
			// (x,y,1)Q(x,y,1)^t, where Q=q[i]
			for (i = 0; i < m; i++) {
				d = dir[i].x * dir[i].x + dir[i].y * dir[i].y;
				if (d == 0) {
					for (j = 0; j < 3; j++) {
						for (k = 0; k < 3; k++) {
							q[i][j][k] = 0;
						}
					}
				} else {
					v[0] = dir[i].y;
					v[1] = -dir[i].x;
					v[2] = -v[1] * ctr[i].y - v[0] * ctr[i].x;
					for (l = 0; l < 3; l++) {
						for (k = 0; k < 3; k++) {
							q[i][l][k] = v[l] * v[k] / d;
						}
					}
				}
			}
			
			// now calculate the "intersections" of consecutive segments.
			// Instead of using the actual intersection, we find the point
			// within a given unit square which minimizes the square distance to
			// the two lines.
			for (i = 0; i < m; i++)
			{
				var Q:Vector.<Vector.<Number>> = new Vector.<Vector.<Number>>(3);
				var w:Point = new Point();
				var dx:Number;
				var dy:Number;
				var det:Number;
				var min:Number; // minimum for minimum of quad. form
				var cand:Number; // candidate for minimum of quad. form
				var xmin:Number; // coordinate of minimum
				var ymin:Number; // coordinate of minimum
				var z:int;

				for (j = 0; j < 3; j++) {
					Q[j] = new Vector.<Number>(3);
				}
				
				// let s be the vertex, in coordinates relative to x0/y0
				s.x = pt[po[i]].x - x0;
				s.y = pt[po[i]].y - y0;
				
				// intersect segments i-1 and i
				j = mod(i - 1, m);
				
				// add quadratic forms
				for (l = 0; l < 3; l++) {
					for (k = 0; k < 3; k++) {
						Q[l][k] = q[j][l][k] + q[i][l][k];
					}
				}
				
				while (true)
				{
					/* minimize the quadratic form Q on the unit square */
					/* find intersection */
					det = Q[0][0] * Q[1][1] - Q[0][1] * Q[1][0];
					if (det != 0) {
						w.x = (-Q[0][2] * Q[1][1] + Q[1][2] * Q[0][1]) / det;
						w.y = (Q[0][2] * Q[1][0] - Q[1][2] * Q[0][0]) / det;
						break;
					}
					
					// matrix is singular - lines are parallel. Add another,
					// orthogonal axis, through the center of the unit square
					if (Q[0][0] > Q[1][1]) {
						v[0] = -Q[0][1];
						v[1] = Q[0][0];
					} else if (Q[1][1] != 0) {
						v[0] = -Q[1][1];
						v[1] = Q[1][0];
					} else {
						v[0] = 1;
						v[1] = 0;
					}
					
					d = v[0] * v[0] + v[1] * v[1];
					v[2] = -v[1] * s.y - v[0] * s.x;
					for (l = 0; l < 3; l++) {
						for (k = 0; k < 3; k++) {
							Q[l][k] += v[l] * v[k] / d;
						}
					}
				}
				
				dx = Math.abs(w.x - s.x);
				dy = Math.abs(w.y - s.y);
				if (dx <= 0.5 && dy <= 0.5) {
					// - 1 because we have a additional border set to the bitmap
					path.curves.vertex[i] = new Point(w.x + x0, w.y + y0);
					continue;
				}
				
				// the minimum was not in the unit square;
				// now minimize quadratic on boundary of square
				min = quadform(Q, s);
				xmin = s.x;
				ymin = s.y;
				
				if (Q[0][0] != 0) {
					for (z = 0; z < 2; z++) {
						// value of the y-coordinate
						w.y = s.y - 0.5 + z;
						w.x = -(Q[0][1] * w.y + Q[0][2]) / Q[0][0];
						dx = Math.abs(w.x - s.x);
						cand = quadform(Q, w);
						if (dx <= 0.5 && cand < min) {
							min = cand;
							xmin = w.x;
							ymin = w.y;
						}
					}
				}
				
				if (Q[1][1] != 0) {
					for (z = 0; z < 2; z++)
					{
						// value of the x-coordinate
						w.x = s.x - 0.5 + z;
						w.y = -(Q[1][0] * w.x + Q[1][2]) / Q[1][1];
						dy = Math.abs(w.y - s.y);
						cand = quadform(Q, w);
						if (dy <= 0.5 && cand < min) {
							min = cand;
							xmin = w.x;
							ymin = w.y;
						}
					}
				}
				
				// check four corners
				for (l = 0; l < 2; l++) {
					for (k = 0; k < 2; k++) {
						w.x = s.x - 0.5 + l;
						w.y = s.y - 0.5 + k;
						cand = quadform(Q, w);
						if (cand < min) {
							min = cand;
							xmin = w.x;
							ymin = w.y;
						}
					}
				}
				
				// - 1 because we have a additional border set to the bitmap
				path.curves.vertex[i] = new Point(xmin + x0 - 1, ymin + y0 - 1);
				continue;
			}
		}

		/////////////////////////////////////////////////////////////////////////
		// STAGE 4
		// Smoothing and corner analysis (Sec. 2.3.3).
		/////////////////////////////////////////////////////////////////////////

		private function smooth(curve:PrivCurve, sign:int, alphaMax:Number):void
		{
			var m:int = curve.n;
			
			var i:int;
			var j:int;
			var k:int;
			var dd:Number;
			var denom:Number;
			var alpha:Number;
			
			var p2:Point;
			var p3:Point;
			var p4:Point;
			
			if (sign < 0) {
				/* reverse orientation of negative paths */
				for (i = 0, j = m - 1; i < j; i++, j--) {
					var tmp:Point = curve.vertex[i];
					curve.vertex[i] = curve.vertex[j];
					curve.vertex[j] = tmp;
				}
			}
			
			/* examine each vertex and find its best fit */
			for (i = 0; i < m; i++)
			{
				j = mod(i + 1, m);
				k = mod(i + 2, m);
				p4 = interval(1 / 2.0, curve.vertex[k], curve.vertex[j]);
				
				denom = ddenom(curve.vertex[i], curve.vertex[k]);
				if (denom != 0) {
					dd = dpara(curve.vertex[i], curve.vertex[j], curve.vertex[k]) / denom;
					dd = Math.abs(dd);
					alpha = (dd > 1) ? (1 - 1.0 / dd) : 0;
					alpha = alpha / 0.75;
				} else {
					alpha = 4 / 3;
				}
				
				// remember "original" value of alpha */
				curve.alpha0[j] = alpha;
				  
				if (alpha > alphaMax) {
					// pointed corner
					curve.tag[j] = POTRACE_CORNER;
					curve.controlPoints[j][1] = curve.vertex[j];
					curve.controlPoints[j][2] = p4;
				} else {
					if (alpha < 0.55) {
						alpha = 0.55;
					} else if (alpha > 1) {
						alpha = 1;
					}
					p2 = interval(.5 + .5 * alpha, curve.vertex[i], curve.vertex[j]);
					p3 = interval(.5 + .5 * alpha, curve.vertex[k], curve.vertex[j]);
					curve.tag[j] = POTRACE_CURVETO;
					curve.controlPoints[j][0] = p2;
					curve.controlPoints[j][1] = p3;
					curve.controlPoints[j][2] = p4;
				}
				// store the "cropped" value of alpha
				curve.alpha[j] = alpha;
				curve.beta[j] = 0.5;
			}
		}

		private function pathlist_to_curvearrayslist(plists:Array):Array
		{
			var res:Array = [];
			
			/* call downstream function with each path */
			for (var j:int = 0; j < plists.length; j++)
			{
				var plist:Array = plists[j] as Array;
				var clist:Array = [];
				res.push(clist);

                for (var i:int = 0; i < plist.length; i++)
                {
                    var p:Path = plist[i] as Path;
                    var A:Point = p.curves.controlPoints[p.curves.n - 1][2];
                    var curves:Array = [];
                    for (var k:int = 0; k < p.curves.n; k++)
                    {
						var C:Point = p.curves.controlPoints[k][0];
						var D:Point = p.curves.controlPoints[k][1];
						var E:Point = p.curves.controlPoints[k][2];
						if (p.curves.tag[k] == POTRACE_CORNER) {
							add_curve(curves, A, A, D, D);
							add_curve(curves, D, D, E, E);
						} else {
							add_curve(curves, A, C, D, E);
						}
						A = E;
					}
					if (curves.length > 0)
					{
						var cl:Curve = curves[curves.length - 1] as Curve;
						var cf:Curve = curves[0] as Curve;
						if ((cl.kind == CurveKind.LINE) && (cf.kind == CurveKind.LINE)
							&& iprod(cl.b, cl.a, cf.b) < 0
							&& (Math.abs(xprodf(
								new Point(cf.b.x - cf.a.x, cf.b.y - cf.a.y),
								new Point(cl.a.x - cl.a.x, cl.b.y - cl.a.y))) < 0.01))
						{
							curves[0] = new Curve(CurveKind.LINE, cl.a, cl.a, cl.a, cf.b);
							curves.pop();
						}
						var curveList:Array = [];
						for (var ci:int = 0; ci < curves.length; ci++) {
							curveList.push(curves[ci]);
						}
						clist.push(curveList);
					}
                }
			}
			return res;
		}

		private function add_curve(curves:Array, a:Point, cpa:Point, cpb:Point, b:Point):void
		{
			var kind:int;
			if ((Math.abs(xprodf(new Point(cpa.x - a.x, cpa.y - a.y), new Point(b.x - a.x, b.y - a.y))) < 0.01) &&
				(Math.abs(xprodf(new Point(cpb.x - b.x, cpb.y - b.y), new Point(b.x - a.x, b.y - a.y))) < 0.01)) {
				//trace("line");
				kind = CurveKind.LINE;
			} else {
				//trace("bezier");
				kind = CurveKind.BEZIER;
			}
			if ((kind == CurveKind.LINE)) {
			    if ((curves.length > 0) && (Curve(curves[curves.length - 1]).kind == CurveKind.LINE)) {
			        var c:Curve = curves[curves.length - 1] as Curve;
			        if ((Math.abs(xprodf(new Point(c.b.x - c.a.x, c.b.y - c.a.y), new Point(b.x - a.x, b.y - a.y))) < 0.01) && (iprod(c.b, c.a, b) < 0)) {
			            curves[curves.length - 1] = new Curve(kind, c.a, c.a, c.a, b);
			        } else {
			            curves.push(new Curve(CurveKind.LINE, a, cpa, cpb, b));
			        }
			    } else {
			        curves.push(new Curve(CurveKind.LINE, a, cpa, cpb, b));
			    }
			} else {
			    curves.push(new Curve(CurveKind.BEZIER, a, cpa, cpb, b));
			}
		}

		/*
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

		private function dump_path_lists(plists:Array):void
		{
			for (var j:int = 0; j < plists.length; j++) {
				trace("Path List " + j);
				var plist:Array = plists[j] as Array;
				for (var i:int = 0; i < plist.length; i++) {
					var path:Path = plist[i] as Path;
					trace(path.toString(2));
				}
			}
		}
		*/

		/////////////////////////////////////////////////////////////////////////
		// AUXILIARY FUNCTIONS
		/////////////////////////////////////////////////////////////////////////
		
		/*
		 * Return a direction that is 90 degrees counterclockwise from p2-p0,
		 * but then restricted to one of the major wind directions (n, nw, w, etc)
		 */
   		private function dorth_infty(p0:Point, p2:Point):PointInt
		{
			return new PointInt(-sign(p2.y - p0.y), sign(p2.x - p0.x));
		}
		
		/*
		 * Return (p1-p0) x (p2-p0), the area of the parallelogram
		 */
		private function dpara(p0:Point, p1:Point, p2:Point):Number {
			return (p1.x - p0.x) * (p2.y - p0.y) - (p2.x - p0.x) * (p1.y - p0.y);
		}
		
		/*
		 * ddenom/dpara have the property that the square of radius 1 centered
		 * at p1 intersects the line p0p2 iff |dpara(p0,p1,p2)| <= ddenom(p0,p2)
		 */
		private function ddenom(p0:Point, p2:Point):Number
		{
			var r:PointInt = dorth_infty(p0, p2);
			return r.y * (p2.x - p0.x) - r.x * (p2.y - p0.y);
		}

		/*
		 * Return true if a <= b < c < a, in a cyclic sense (mod n)
		 */
		private function cyclic(a:int, b:int, c:int):Boolean
		{
			if (a <= c) {
				return (a <= b && b < c);
			} else {
				return (a <= b || b < c);
			}
		}
		
		/*
		 * Determine the center and slope of the line i..j. Assume i < j.
		 * Needs "sum" components of p to be set.
		 */
		private function pointslope(path:Path, i:int, j:int, ctr:Point, dir:Point):void
		{
			// assume i < j
			var n:int = path.pt.length;
			var sums:Vector.<SumStruct> = path.sums;
			var l:Number;
			var r:int = 0; // rotations from i to j
			
			while (j >= n) {
				j -= n;
				r++;
			}
			while (i >= n) {
			    i -= n;
			    r--;
			}
			while (j < 0) {
			    j += n;
			    r--;
			}
			while (i < 0) {
			    i += n;
			    r++;
			}
			
			var x:Number = sums[j + 1].x - sums[i].x + r * sums[n].x;
			var y:Number = sums[j + 1].y - sums[i].y + r * sums[n].y;
			var x2:Number = sums[j + 1].x2 - sums[i].x2 + r * sums[n].x2;
			var xy:Number = sums[j + 1].xy - sums[i].xy + r * sums[n].xy;
			var y2:Number = sums[j + 1].y2 - sums[i].y2 + r * sums[n].y2;
			var k:Number = j + 1 - i + r * n;
			
			ctr.x = x / k;
			ctr.y = y / k;
			
			var a:Number = (x2 - x * x / k) / k;
			var b:Number = (xy - x * y / k) / k;
			var c:Number = (y2 - y * y / k) / k;
			
			var lambda2:Number = (a + c + Math.sqrt((a - c) * (a - c) + 4 * b * b)) / 2; // larger e.value
			
			// now find e.vector for lambda2
			a -= lambda2;
			c -= lambda2;
			
			if (Math.abs(a) >= Math.abs(c)) {
				l = Math.sqrt(a * a + b * b);
				if (l != 0) {
					dir.x = -b / l;
					dir.y = a / l;
				}
			} else {
				l = Math.sqrt(c * c + b * b);
				if (l != 0) {
					dir.x = -c / l;
					dir.y = b / l;
				}
			}
			if (l == 0) {
				// sometimes this can happen when k=4:
				// the two eigenvalues coincide
				dir.x = dir.y = 0;
			}
		}

		/*
		 * Apply quadratic form Q to vector w = (w.x, w.y)
		 */
		private function quadform(Q:Vector.<Vector.<Number>>, w:Point):Number
		{
			var sum:Number = 0;
			var v:Vector.<Number> = new Vector.<Number>(3);
			v[0] = w.x;
			v[1] = w.y;
			v[2] = 1;
			for (var i:int = 0; i < 3; i++) {
				for (var j:int = 0; j < 3; j++) {
					sum += v[i] * Q[i][j] * v[j];
				}
			}
			return sum;
		}

		/*
		 * Calculate p1 x p2
		 * (Integer version)
		 */
		private function xprod(p1:PointInt, p2:PointInt):int
		{
			return p1.x * p2.y - p1.y * p2.x;
		}
		
		/*
		 * Calculate p1 x p2
		 * (Floating point version)
		 */
		private function xprodf(p1:Point, p2:Point):int
		{
			return p1.x * p2.y - p1.y * p2.x;
		}
		
        /*
         * Calculate (p1 - p0) * (p2 - p0)
         */
        private function iprod(p0:Point, p1:Point, p2:Point):Number
        {
            return (p1.x - p0.x) * (p2.x - p0.x) + (p1.y - p0.y) * (p2.y - p0.y);
        }

        /*
         * Calculate (p1 - p0) * (p3 - p2)
         */
        //private function iprod1(p0:Point, p1:Point, p2:Point, p3:Point):Number
        //{
        //   return (p1.x - p0.x) * (p3.x - p2.x) + (p1.y - p0.y) * (p3.y - p2.y);
        //}

		private function interval(lambda:Number, a:Point, b:Point):Point
		{
			return new Point(a.x + lambda * (b.x - a.x), a.y + lambda * (b.y - a.y));
		}
		
		private function abs(a:int):int
		{
			return (a > 0) ? a : -a;
		}
		
		private function floordiv(a:int, n:int):int
		{
			return (a >= 0) ? a / n : -1 - (-1 - a) / n;
		}
		
		private function min(a:int, b:int):int
		{
			return (a < b) ? a : b;
		}
		
		/*
		private function max(a:int, b:int):int
		{
			return (a > b) ? a : b;
		}
		*/
		
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
