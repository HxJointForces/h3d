package h3d.prim;
using h3d.fbx.Data;
import h3d.impl.Buffer.BufferOffset;

class FBXModel extends MeshPrimitive {

	public var geom(default, null) : h3d.fbx.Geometry;
	public var skin : h3d.anim.Skin;
	public var multiMaterial : Bool;
	var bounds : h3d.col.Bounds;
	var curMaterial : Int;
	var matIndexes : Array<h3d.impl.Indexes>;

	public function new(g) {
		this.geom = g;
		curMaterial = -1;
	}
	
	public function getVerticesCount() {
		return Std.int(geom.getVertices().length / 3);
	}
	
	override function getBounds() {
		if( bounds != null )
			return bounds;
		bounds = new h3d.col.Bounds();
		var verts = geom.getVertices();
		var gt = geom.getGeomTranslate();
		if( gt == null ) gt = new h3d.prim.Point();
		if( verts.length > 0 ) {
			bounds.xMin = bounds.xMax = verts[0] + gt.x;
			bounds.yMin = bounds.yMax = verts[1] + gt.y;
			bounds.zMin = bounds.zMax = verts[2] + gt.z;
		}
		var pos = 3;
		for( i in 1...Std.int(verts.length / 3) ) {
			var x = verts[pos++] + gt.x;
			var y = verts[pos++] + gt.y;
			var z = verts[pos++] + gt.z;
			if( x > bounds.xMax ) bounds.xMax = x;
			if( x < bounds.xMin ) bounds.xMin = x;
			if( y > bounds.yMax ) bounds.yMax = y;
			if( y < bounds.yMin ) bounds.yMin = y;
			if( z > bounds.zMax ) bounds.zMax = z;
			if( z < bounds.zMin ) bounds.zMin = z;
		}
		return bounds;
	}
	
	override function render( engine : h3d.Engine ) {
		if( curMaterial < 0 ) {
			super.render(engine);
			return;
		}
		if( indexes == null || indexes.isDisposed() )
			alloc(engine);
		var idx = indexes;
		indexes = matIndexes[curMaterial];
		if( indexes != null ) super.render(engine);
		indexes = idx;
		curMaterial = -1;
	}
	
	override function selectMaterial( material : Int ) {
		curMaterial = material;
	}
	
	override function dispose() {
		super.dispose();
		if( matIndexes != null ) {
			for( i in matIndexes )
				if( i != null )
					i.dispose();
			matIndexes = null;
		}
	}
	
	override function alloc( engine : h3d.Engine ) {
		dispose();
		
		var verts = geom.getVertices();
		var norms = geom.getNormals();
		var tuvs = geom.getUVs()[0];
		var colors = geom.getColors();
		var mats = multiMaterial ? geom.getMaterials() : null;
		
		var gt = geom.getGeomTranslate();
		if( gt == null ) gt = new h3d.prim.Point();
		
		var idx = new flash.Vector<UInt>();
		var midx = new Array<flash.Vector<UInt>>();
		var pbuf = new flash.Vector<Float>(), nbuf = (norms == null ? null : new flash.Vector<Float>()), sbuf = (skin == null ? null : new flash.utils.ByteArray()), tbuf = (tuvs == null ? null : new flash.Vector<Float>());
		var cbuf = (colors == null ? null : new flash.Vector<Float>());
		var pout = 0, nout = 0, sout = 0, tout = 0, cout = 0;
		
		if( sbuf != null ) sbuf.endian = flash.utils.Endian.LITTLE_ENDIAN;
		
		// triangulize indexes : format is  A,B,...,-X : negative values mark the end of the polygon
		var count = 0, pos = 0, matPos = 0;
		var index = geom.getPolygons();
		for( i in index ) {
			count++;
			if( i < 0 ) {
				index[pos] = -i - 1;
				var start = pos - count + 1;
				for( n in 0...count ) {
					var k = n + start;
					var vidx = index[k];
					
					var x = verts[vidx * 3] + gt.x;
					var y = verts[vidx * 3 + 1] + gt.y;
					var z = verts[vidx * 3 + 2] + gt.z;
					pbuf[pout++] = x;
					pbuf[pout++] = y;
					pbuf[pout++] = z;

					if( nbuf != null ) {
						nbuf[nout++] = norms[k*3];
						nbuf[nout++] = norms[k*3 + 1];
						nbuf[nout++] = norms[k*3 + 2];
					}

					if( tbuf != null ) {
						var iuv = tuvs.index[k];
						tbuf[tout++] = tuvs.values[iuv*2];
						tbuf[tout++] = 1 - tuvs.values[iuv * 2 + 1];
					}
					
					if( sbuf != null ) {
						var p = vidx * skin.bonesPerVertex;
						var idx = 0;
						for( i in 0...skin.bonesPerVertex ) {
							sbuf.writeFloat(skin.vertexWeights[p + i]);
							idx = (skin.vertexJoints[p + i] << (8*i)) | idx;
						}
						sbuf.writeUnsignedInt(idx);
					}
					
					if( cbuf != null ) {
						var icol = colors.index[k];
						cbuf[cout++] = colors.values[icol * 4];
						cbuf[cout++] = colors.values[icol * 4 + 1];
						cbuf[cout++] = colors.values[icol * 4 + 2];
					}
				}
				// polygons are actually triangle fans
				for( n in 0...count - 2 ) {
					idx.push(start + n);
					idx.push(start + count - 1);
					idx.push(start + n + 1);
				}
				// by-material index
				if( mats != null ) {
					var mid = mats[matPos++];
					var idx = midx[mid];
					if( idx == null ) {
						idx = new flash.Vector<UInt>();
						midx[mid] = idx;
					}
					for( n in 0...count - 2 ) {
						idx.push(start + n);
						idx.push(start + count - 1);
						idx.push(start + n + 1);
					}
				}
				index[pos] = i; // restore
				count = 0;
			}
			pos++;
		}
		
		addBuffer("pos", engine.mem.allocVector(pbuf, 3, 0));
		if( nbuf != null ) addBuffer("normal", engine.mem.allocVector(nbuf, 3, 0));
		if( tbuf != null ) addBuffer("uv", engine.mem.allocVector(tbuf, 2, 0));
		if( sbuf != null ) {
			var nverts = Std.int(sbuf.length / ((skin.bonesPerVertex + 1) * 4));
			var skinBuf = engine.mem.alloc(nverts, skin.bonesPerVertex + 1, 0);
			skinBuf.upload(sbuf, 0, nverts);
			addBuffer("weights", skinBuf, 0);
			addBuffer("indexes", skinBuf, skin.bonesPerVertex);
		}
		if( cbuf != null ) addBuffer("color", engine.mem.allocVector(cbuf, 3, 0));
		
		indexes = engine.mem.allocIndex(idx);
		if( mats != null ) {
			matIndexes = [];
			for( i in midx )
				matIndexes.push(i == null ? null : engine.mem.allocIndex(i));
		}
	}
	
}
