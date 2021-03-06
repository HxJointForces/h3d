package h2d.comp;

@:access(h2d.comp.Input.scene)
class Input extends Component {
	
	var input : h2d.Interactive;
	var tf : h2d.Text;
	var cursor : h2d.Bitmap;
	var cursorPos(default,set) : Int;
	
	public var value(default, set) : String;
	
	public function new(?parent) {
		super("input",parent);
		tf = new h2d.Text(null, this);
		input = new h2d.Interactive(0, 0, bg);
		input.cursor = TextInput;
		cursor = new h2d.Bitmap(null, bg);
		cursor.visible = false;
		var active = false;
		input.onPush = function(_) {
			focus();
		};
		input.onOver = function(_) {
			addClass(":hover");
		};
		input.onOut = function(_) {
			active = false;
			removeClass(":hover");
		};
		input.onFocus = function(_) {
			addClass(":focus");
			cursor.visible = true;
		};
		input.onFocusLost = function(_) {
			removeClass(":focus");
			cursor.visible = false;
		};
		input.onKeyDown = function(e:Event) {
			if( input.hasFocus() ) {
				// BACK
				switch( e.keyCode ) {
				case Key.LEFT:
					if( cursorPos > 0 )
						cursorPos--;
				case Key.RIGHT:
					if( cursorPos < value.length )
						cursorPos++;
				case Key.HOME:
					cursorPos = 0;
				case Key.END:
					cursorPos = value.length;
				case Key.DELETE:
					value = value.substr(0, cursorPos) + value.substr(cursorPos + 1);
					onChange(value);
					return;
				case Key.BACK:
					value = value.substr(0, cursorPos - 1) + value.substr(cursorPos);
					cursorPos--;
					onChange(value);
					return;
				}
				if( e.charCode != 0 ) {
					value = value.substr(0, cursorPos) + String.fromCharCode(e.charCode) + value.substr(cursorPos);
					cursorPos++;
					onChange(value);
				}
			}
		};
		this.value = "";
	}
	
	function set_cursorPos(v:Int) {
		cursor.x = tf.calcTextWidth(value.substr(0, v)) + extLeft();
		return cursorPos = v;
	}

	public function focus() {
		input.focus();
		cursorPos = value.length;
	}
	
	function get_value() {
		return tf.text;
	}
	
	function set_value(t) {
		needRebuild = true;
		return value = t;
	}
	
	override function resize( ctx : Context ) {
		if( ctx.measure ) {
			tf.font = getFont();
			tf.textColor = style.color;
			tf.text = value;
			tf.filter = true;
			contentWidth = tf.textWidth;
			contentHeight = tf.textHeight;
			if( cursorPos < 0 ) cursorPos = 0;
			if( cursorPos > value.length ) cursorPos = value.length;
			cursorPos = cursorPos;
		}
		super.resize(ctx);
		if( !ctx.measure ) {
			input.width = width - (style.marginLeft + style.marginRight);
			input.height = height - (style.marginTop + style.marginBottom);
			cursor.y = extTop() - 1;
			cursor.tile = h2d.Tile.fromColor(style.cursorColor | 0xFF000000, 1, Std.int(height - extTop() - extBottom() + 2));
		}
	}
	
	public dynamic function onChange( value : String ) {
	}
	
}
