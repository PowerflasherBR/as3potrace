package 
{
	import com.powerflasher.as3potrace.POTrace;
	import flash.filters.BitmapFilterQuality;
	import flash.filters.BlurFilter;
	import flash.filters.ColorMatrixFilter;
	import flash.geom.Point;
	import flash.filters.BitmapFilter;
	import com.bit101.components.PushButton;

	import flash.display.Bitmap;
	import flash.display.BitmapData;
	import flash.display.Loader;
	import flash.display.LoaderInfo;
	import flash.display.PixelSnapping;
	import flash.display.Sprite;
	import flash.display.StageAlign;
	import flash.display.StageScaleMode;
	import flash.events.Event;
	import flash.geom.Matrix;
	import flash.net.FileFilter;
	import flash.net.FileReference;
	import flash.utils.ByteArray;

	public class Main extends Sprite
	{
		public function Main()
		{
			stage.align = StageAlign.TOP_LEFT;
			stage.scaleMode = StageScaleMode.NO_SCALE
			addChild(new PushButton(this, 10, 10, "Load Image", function():void {
				var ref:FileReference = new FileReference();
				ref.addEventListener(Event.SELECT, function(e:Event):void { ref.load(); });
				ref.addEventListener(Event.COMPLETE, function(e:Event):void { loadBytes(ref.data); });
				ref.browse([new FileFilter("PNG (*.png)", "*.png"), new FileFilter("JPG (*.jpg)", "*.jpg"), new FileFilter("GIF (*.gif)", "*.gif")]);
			}));
		}
		
		protected function loadBytes(image:ByteArray):void
		{
			var loader:Loader = new Loader();
			loader.contentLoaderInfo.addEventListener(Event.INIT, initHandler);
			loader.loadBytes(image);
		}

		protected function initHandler(event:Event):void
		{
			var loaderInfo:LoaderInfo = event.target as LoaderInfo;
			var loader:Loader = loaderInfo.loader;

			var xs:Number = (stage.stageWidth - 20) / loader.width;
			var ys:Number = (stage.stageHeight - 50) / loader.height;
			var s:Number = Math.min(xs, ys);
			
			var bmd:BitmapData = new BitmapData(loader.width * s, loader.height * s, false);
			var matrix:Matrix = new Matrix();
			matrix.createBox(s, s);
			bmd.draw(loader.content, matrix, null, null, null, true);
			bmd.applyFilter(bmd, bmd.rect, new Point(0, 0), grayscaleFilter);
			bmd.applyFilter(bmd, bmd.rect, new Point(0, 0), blurFilter);
			
			var bmd2:BitmapData = new BitmapData(bmd.width, bmd.height, false, 0xffffff);
			bmd2.threshold(bmd, bmd.rect, new Point(0, 0), ">=", 0x808080, 0x000000, 0xffffff, false);
			
			var bm:Bitmap = new Bitmap(bmd2, PixelSnapping.AUTO, true);
			bm.x = 10;
			bm.y = 40;
			addChild(bm);
			
			var potrace:POTrace = new POTrace();
			var shapes:Array = potrace.traceBitmap(bmd2);
			trace(shapes);
		}
		
		protected function get grayscaleFilter():BitmapFilter
		{
			var r:Number = 0.212671;
			var g:Number = 0.715160;
			var b:Number = 0.072169;
			
			return new ColorMatrixFilter([
				r, g, b, 0, 0,
				r, g, b, 0, 0,
				r, g, b, 0, 0,
				0, 0, 0, 1, 0
			]);
		}
		
		protected function get blurFilter():BitmapFilter
		{
			return new BlurFilter(8, 8, BitmapFilterQuality.HIGH);
		}
	}
}
