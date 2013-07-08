package h2d.comp;

#if hscript
private class CustomInterp extends hscript.Interp {
	override function fcall(o:Dynamic, f:String, args:Array<Dynamic>):Dynamic {
		if( Std.is(o, h2d.css.JQuery) && Reflect.field(o,f) == null ) {
			var rf = args.length == 0 ? "_get_" + f : "_set_" + f;
			if( Reflect.field(o, rf) == null ) throw "JQuery don't have " + f + " implemented";
			f = rf;
		}
		return super.fcall(o, f, args);
	}
}
#end

class Parser {
	
	var api : {};
	var comps : Map<String, haxe.xml.Fast -> Component -> Component>;
	
	public function new(?api) {
		this.api = api;
		comps = new Map();
	}
	
	public function build( x : haxe.xml.Fast, ?parent : Component ) {
		var c : Component;
		switch( x.name.toLowerCase() ) {
		case "body":
			c = new Box(Absolute, parent);
		case "style":
			parent.addCss(x.innerData);
			return null;
		case "div", "box":
			c = new Box(parent);
		case "button":
			c = new Button(x.has.value ? x.att.value : "", parent);
		case "slider":
			c = new Slider(parent);
		case "label", "span":
			c = new Label(x.x.firstChild() == null ? "" : x.innerData, parent);
		case "checkbox":
			c = new Checkbox(parent);
		case "itemlist":
			c = new ItemList(parent);
		case "input":
			c = new Input(parent);
		case "colorpicker":
			c = new ColorPicker(parent);
		case "gradienteditor":
			c = new GradientEditor(parent);
		case n:
			var make = comps.get(n);
			if( make != null )
				c = make(x, parent);
			else
				throw "Unknown node " + n;
		}
		for( n in x.x.attributes() ) {
			var v = x.x.get(n);
			switch( n.toLowerCase() ) {
			case "class":
				for( cl in v.split(" ") ) {
					var cl = StringTools.trim(cl);
					if( cl.length > 0 ) c.addClass(cl);
				}
			case "id":
				c.id = v;
			case "value":
				switch( c.name ) {
				case "slider":
					var c : Slider = cast c;
					c.value = Std.parseFloat(v);
				case "input":
					var c : Input = cast c;
					c.value = v;
				default:
				}
			case "onclick":
				switch( c.name ) {
				case "button":
					var c : Button = cast c;
					c.onClick = makeScript(c,v);
				default:
				}
			case "onchange":
				switch( c.name ) {
				case "slider":
					var c : Slider = cast c;
					var s = makeScript(c,v);
					c.onChange = function(_) s();
				case "checkbox":
					var c : Checkbox = cast c;
					var s = makeScript(c,v);
					c.onChange = function(_) s();
				case "itemlist":
					var c : ItemList = cast c;
					var s = makeScript(c,v);
					c.onChange = function(_) s();
				case "input":
					var c : Input = cast c;
					var s = makeScript(c,v);
					c.onChange = function(_) s();
				default:
				}
			case "style":
				var s = new h2d.css.Style();
				new h2d.css.Parser().parse(v, s);
				c.setStyle(s);
			case "selected":
				switch( c.name ) {
				case "itemlist":
					var c : ItemList = cast c;
					c.selected = Std.parseInt(v);
				default:
				}
			case "checked":
				switch( c.name ) {
				case "checkbox":
					var c : Checkbox = cast c;
					c.checked = true;
				default:
				}
			case "x":
				c.x = Std.parseFloat(v);
			case "y":
				c.y = Std.parseFloat(v);
			case n:
				throw "Unknown attrib " + n;
			}
		}
		for( e in x.elements )
			build(e, c);
		return c;
	}
	
	public function register(name, make) {
		this.comps.set(name, make);
	}
	
	function makeScript( c : Component, script : String ) {
		#if hscript
		var p = new hscript.Parser();
		p.identChars += "$";
		var e = null;
		try {
			e = p.parseString(script);
		} catch( e : hscript.Expr.Error ) {
			throw "Invalid Script line " + p.line + " (" + e+ ")";
		}
		var i = new CustomInterp();
		i.variables.set("api", api);
		i.variables.set("this", c);
		i.variables.set("$", function(rq) return new h2d.css.JQuery(c,rq));
		return function() try i.execute(e) catch( e : Dynamic ) throw "Error while running script " + script + " (" + e + ")";
		#else
		return function() throw "Please compile with -lib hscript to get script access";
		#end
	}
	
	public static function fromHtml( html : String, ?api : {} ) : Component {
		function lookupBody(x:Xml) {
			if( x.nodeType == Xml.Element && x.nodeName.toLowerCase() == "body" )
				return x;
			if( x.nodeType == Xml.PCData )
				return null;
			for( e in x ) {
				var v = lookupBody(e);
				if( v != null ) return v;
			}
			return null;
		}
		var x = Xml.parse(html);
		var body = lookupBody(x);
		if( body == null ) body = x;
		return new Parser(api).build(new haxe.xml.Fast(body),null);
	}
	
}