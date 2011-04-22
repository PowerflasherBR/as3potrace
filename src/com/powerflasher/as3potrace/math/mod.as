package com.powerflasher.as3potrace.math
{
	public function mod(a:int, n:int):int
	{
		return (a >= n) ? a % n : ((a >= 0) ? a : n - 1 - (-1 - a) % n);
	}
}
