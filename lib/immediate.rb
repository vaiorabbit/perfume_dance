# -*- Coding: utf-8 -*-

# Ref.:
# * C++ code to emulate openGL old direct mode drawing http://rodolphe-vaillant.fr/?e=8
# * Blinn–Phong shading model http://en.wikipedia.org/wiki/Blinn%E2%80%93Phong_shading_model
# * GLSL : common mistakes http://www.opengl.org/wiki/GLSL_:_common_mistakes
# * Sampler (GLSL) https://www.opengl.org/wiki/Sampler_(GLSL)
require_relative 'shader'
require_relative 'buffer_object'

class ImmediateDraw

  NullPtr = Fiddle::Pointer[0]

  module Attribute
    POSITION  = 0
    NORMAL    = 1
    TEXCOORD  = 2
    COLOR     = 3
    COUNT     = 4
  end

  module Mode
    POINTS          = 0
    LINE_STRIP      = 1
    LINE_LOOP       = 2
    LINES           = 3
    TRIANGLE_FAN    = 4
    TRIANGLES       = 5
    TRIANGLE_STRIP  = 6
    QUADS           = 7
    QUAD_STRIP      = 8
    COUNT           = 9
    UNKNOWN         = 10
  end

  @@mode_map = {
    Mode::POINTS          => GL::POINTS,
    Mode::LINE_STRIP      => GL::LINE_STRIP,
    Mode::LINE_LOOP       => GL::LINE_LOOP,
    Mode::LINES           => GL::LINES,
    Mode::TRIANGLE_FAN    => GL::TRIANGLE_FAN,
    Mode::TRIANGLES       => GL::TRIANGLES,
    Mode::TRIANGLE_STRIP  => GL::TRIANGLE_STRIP,
    Mode::QUADS           => GL::QUADS,
    Mode::QUAD_STRIP      => GL::QUAD_STRIP,
  }

  @@attribute_size = {
    Attribute::POSITION  => 4,  # x, y, z, w
    Attribute::NORMAL    => 3,  # x, y, z
    Attribute::TEXCOORD  => 2,  # u, v
    Attribute::COLOR     => 4,  # r, g, b, a
  }

  @@immediate_shader = nil
  @@immediate_vert_shader_source = <<-VERT_SHADER_SRC
  #version 410
  layout(location = 0) in vec4 vi_vecPosition;
  layout(location = 1) in vec3 vi_vecNormal;
  layout(location = 2) in vec4 vi_vecTexcoord;
  layout(location = 3) in vec4 vi_rgbaColor;

  out vec3 fi_vecNormalInView;
  out vec4 fi_vecTexcoord;
  out vec4 fi_rgbaColor;
  out vec3 fi_vecLightDirInView;
  out vec3 fi_vecHalfwayDir;

  uniform vec3 vecLightPosInView;
  uniform mat4 mtxMV;
  uniform mat4 mtxMVP;
  uniform mat4 mtxNormal;

  void main()
  {
    // Preparing for view-space calculation
    vec3 vecVertexPosInView = vec3(mtxMV * vi_vecPosition);
    vec3 vecLightDirInView = normalize(vecLightPosInView - vecVertexPosInView);
    vec3 vecEyeDirInView = normalize(vec3(0.0, 0.0, 0.0) - vecVertexPosInView);
    vec3 vecHalfwayDir = normalize(vecLightDirInView + vecEyeDirInView);

    fi_vecLightDirInView = vecLightDirInView;
    fi_vecHalfwayDir = vecHalfwayDir;

    gl_Position = mtxMVP * vi_vecPosition;
    fi_vecNormalInView = normalize((mtxNormal * vec4(vi_vecNormal,0.0)).xyz);
    fi_vecTexcoord = vi_vecTexcoord;
    fi_rgbaColor = vi_rgbaColor;
  }
  VERT_SHADER_SRC

  @@immediate_frag_shader_source = <<-FRAG_SHADER_SRC
  #version 410
  in vec3 fi_vecNormalInView;
  in vec4 fi_vecTexcoord;
  in vec4 fi_rgbaColor;
  in vec3 fi_vecLightDirInView;
  in vec3 fi_vecHalfwayDir;

  out vec4 fo_rgbaColor;

  uniform vec4 rgbaLightColor;
  uniform int sUseLighting = 0;
  uniform int sUseTexture = 0;
  uniform sampler2D tsDiffuseTexure;

  void main()
  {
    vec4 rgbaDiffuseTexture = texture(tsDiffuseTexure, fi_vecTexcoord.xy);
    if (sUseTexture == 0) {
      rgbaDiffuseTexture = vec4(1.0, 1.0, 1.0, 1.0);
    }

    if (sUseLighting == 1) {
      float fSpecularPower = 4.0, fAmbeintScale = 0.1;
      float NdotL = dot(normalize(fi_vecNormalInView), normalize(fi_vecLightDirInView));
      float NdotH = dot(normalize(fi_vecNormalInView), normalize(fi_vecHalfwayDir));
      vec3 rgbDiffuse = clamp(NdotL, 0.0, 1.0) * fi_rgbaColor.rgb;
      vec3 rgbSpecular = pow(clamp(NdotH, 0.0, 1.0), fSpecularPower) * fi_rgbaColor.rgb;
      vec3 rgbAmbient = fAmbeintScale * fi_rgbaColor.rgb;
      fo_rgbaColor = rgbaDiffuseTexture * (rgbaLightColor * vec4((rgbDiffuse + rgbSpecular) , fi_rgbaColor.a) + vec4(rgbAmbient, 1.0));
    } else {
      fo_rgbaColor = fi_rgbaColor * rgbaDiffuseTexture;
    }
  }
  FRAG_SHADER_SRC

  def self.setup
    @@immediate_shader = Shader.new
    @@immediate_shader.load(vertex_code: @@immediate_vert_shader_source, fragment_code: @@immediate_frag_shader_source)
  end

  def self.release
    @@immediate_shader.delete
  end

  def initialize
    # TBI : 法線自動計算、法線自動正規化、flat/smooth切り替え関連(glProvokingVertex)、バッファの一部書き換え(begin_update/end_update/_gpu_maps, vertex3fでのAttr_id返却)
    @mtx_model = nil
    @mtx_view = nil
    @mtx_proj = nil

    @enable_quad_conversion = true

    @prim_mode = Mode::UNKNOWN
    @begin_called = false

    @bufs = Array.new(Attribute::COUNT) { Array.new(Mode::COUNT) { [] } } # array of Float
    @vbos = Array.new(Attribute::COUNT) { Array.new(Mode::COUNT) { [] } } # array of BufferObject
    @vaos = Array.new(Mode::COUNT) { [] }

    @attribute_value = Array.new(Attribute::COUNT)
    @attribute_value[Attribute::POSITION]  = Array.new(@@attribute_size[Attribute::POSITION])
    @attribute_value[Attribute::NORMAL]    = Array.new(@@attribute_size[Attribute::NORMAL])
    @attribute_value[Attribute::TEXCOORD]  = Array.new(@@attribute_size[Attribute::TEXCOORD])
    @attribute_value[Attribute::COLOR]     = Array.new(@@attribute_size[Attribute::COLOR])

    @light_pos = RVec3.new(0.0, 0.0, 0.0)
    @use_lighting = 0
    @use_texture = 0
  end

  def delete
    Attribute::COUNT.times do |attr_idx|
      Mode::COUNT.times do |mode_idx|
        size = @vbos[attr_idx][mode_idx].length
        @vbos[attr_idx][mode_idx].each do |bufobj|
          bufobj.delete
        end
        @vbos[attr_idx][mode_idx].clear
        @bufs[attr_idx][mode_idx].clear
      end
    end

    # VAO
    Mode::COUNT.times do |mode_idx|
      @vaos[mode_idx].each do |vao_id|
        GL.DeleteVertexArrays(1, [vao_id].pack('L'))
      end
      @vaos[mode_idx].clear
    end
  end

  def set_light_position(x, y, z)
    @light_pos.setElements(x, y, z)
  end

  def set_use_lighting(use)
    @use_lighting = use ? 1 : 0
  end

  def use_lighting?
    return @use_lighting == 1
  end

  def set_use_texture(use)
    @use_texture = use ? 1 : 0
  end

  def use_texture?
    return @use_texture == 1
  end

  def set_use_quad_conversion(use)
    @enable_quad_conversion = use
  end

  def use_quad_conversion?
    return @enable_quad_conversion
  end

  def set_matrix(mtx_model, mtx_view, mtx_proj)
    @mtx_model = mtx_model
    @mtx_view = mtx_view
    @mtx_proj = mtx_proj
  end

  def set_model_matrix(mtx_model)
    @mtx_model = mtx_model
  end

  def vertex3f(x, y, z)
    vertex4f(x, y, z, 1.0)
  end

  def vertex4f(x, y, z, w)
    @attribute_value[Attribute::POSITION][0] = x
    @attribute_value[Attribute::POSITION][1] = y
    @attribute_value[Attribute::POSITION][2] = z
    @attribute_value[Attribute::POSITION][3] = w

    # Copy values into main(cpu) memory
    Attribute::COUNT.times do |attr_idx|
      tail = @bufs[attr_idx][@prim_mode].last
      @@attribute_size[attr_idx].times do |component_idx|
        tail << @attribute_value[attr_idx][component_idx]
      end
    end
  end

  def color3f(r, g, b)
    color4f(r, g, b, 1.0)
  end

  def color4f(r, g, b, a)
    @attribute_value[Attribute::COLOR][0] = r
    @attribute_value[Attribute::COLOR][1] = g
    @attribute_value[Attribute::COLOR][2] = b
    @attribute_value[Attribute::COLOR][3] = a
  end

  def normal3f(x, y, z)
    @attribute_value[Attribute::NORMAL][0] = x
    @attribute_value[Attribute::NORMAL][1] = y
    @attribute_value[Attribute::NORMAL][2] = z
  end

  def texcoord2f(u, v)
    @attribute_value[Attribute::TEXCOORD][0] = u
    @attribute_value[Attribute::TEXCOORD][1] = v
  end

  def begin_primitive(mode)
    raise RuntimeError if @begin_called == true
    @begin_called = true

    @prim_mode = mode

    Attribute::COUNT.times do |attr_idx|
      @bufs[attr_idx][@prim_mode] << []
      @vbos[attr_idx][@prim_mode] << BufferObject.new(GL::ARRAY_BUFFER)
    end

    # Create VAO
    buf = Fiddle::Pointer.malloc(Fiddle::SIZEOF_INT)
    GL.GenVertexArrays(1, buf)
    @vaos[@prim_mode] << buf[0, Fiddle::SIZEOF_INT].unpack1('L')
  end

  def end_primitive
    raise RuntimeError if @begin_called == false
    @begin_called = false

    if use_quad_conversion?
      case @prim_mode
      when Mode::QUADS;      convert_quads_to_tris();
      when Mode::QUAD_STRIP; convert_quad_strip_to_tri_strip();
      end
    end

    vtx_count = @bufs[Attribute::POSITION][@prim_mode].last.length / @@attribute_size[Attribute::POSITION]
    Attribute::COUNT.times do |attr_idx|
      data_ptr = Fiddle::Pointer[@bufs[attr_idx][@prim_mode].last.pack('F*')]
      data_count = @@attribute_size[attr_idx] * vtx_count
      @vbos[attr_idx][@prim_mode].last.set_data(data_ptr, data_count)
    end

    # Register to VAO
    GL.BindVertexArray(@vaos[@prim_mode].last)
    Attribute::COUNT.times do |attr_idx|
      GL.EnableVertexAttribArray(attr_idx)
      @vbos[attr_idx][@prim_mode].last.bind()
      GL.VertexAttribPointer(attr_idx, @@attribute_size[attr_idx], GL::FLOAT, GL::FALSE, 0, NullPtr) # TODO : 頂点インターリーブ化
    end
    GL.BindVertexArray(0)

  end

  def draw
    @@immediate_shader.use
    mtx_MV = @mtx_view * @mtx_model
    mtx_MVP = @mtx_proj * mtx_MV
    mtx_MV_IT = mtx_MV.getInverse.getTransposed

    @@immediate_shader.set_uniform("mtxMV", mtx_MV)
    @@immediate_shader.set_uniform("mtxMVP", mtx_MVP)
    @@immediate_shader.set_uniform("mtxNormal", mtx_MV_IT)

    @@immediate_shader.set_uniform("vecLightPosInView", @light_pos.transformCoord(@mtx_view))

    @@immediate_shader.set_uniform("sUseLighting", @use_lighting);
    @@immediate_shader.set_uniform("sUseTexture", @use_texture);
    @@immediate_shader.set_uniform("rgbaLightColor", 1.0, 1.0, 1.0, 1.0)

    Mode::COUNT.times do |mode_idx|
      end_primitive_count = @bufs[Attribute::POSITION][mode_idx].length
      end_primitive_count.times do |i|
        vtx_count = @bufs[Attribute::POSITION][mode_idx][i].length / @@attribute_size[Attribute::POSITION]
        GL.BindVertexArray(@vaos[mode_idx][i])
        GL.DrawArrays(@@mode_map[mode_idx], 0, vtx_count)
        GL.BindVertexArray(0)
      end
    end
    @@immediate_shader.unuse
  end


  # QUADS -> TRIANGLES 変換
  def convert_quads_to_tris
    Attribute::COUNT.times do |attr_idx|
      buf_quads = @bufs[attr_idx][Mode::QUADS].last # 矩形の頂点要素 (三角形用にコピーしたあとこれは削除)
      buf_tris = [] # 三角形の頂点要素 (上記buf_quadsの内容を三角形用に並べなおしつつコピーするためのバッファ)
      attr_size = @@attribute_size[attr_idx]
      quads_vtxs_count = (buf_quads.length / attr_size)
      quads_count = quads_vtxs_count / 4
      quads_count.times do |quad_idx| # 矩形ごとに繰り返し
        # 矩形1枚の頂点インデックス -> 三角形2枚の頂点インデックス
        vi_quads = [4*quad_idx+0, 4*quad_idx+1, 4*quad_idx+2, 4*quad_idx+3]
        vi_tris  = [vi_quads[0],vi_quads[1],vi_quads[2],  vi_quads[0],vi_quads[2],vi_quads[3]]
        # 矩形1枚の頂点要素を三角形2枚の頂点要素として詰め直す
        vi_tris.each do |ti|
          attr_size.times do |component_idx|
            buf_tris << buf_quads[ti*attr_size+component_idx]
          end
        end
      end
      # raise RuntimeError if buf_quads.length != (2 * buf_tris.length / 3) # 頂点数は矩形1枚の4点から三角形2枚の6点に増えているはず

      # Buffer/VBO 再作成
      @bufs[attr_idx][Mode::QUADS].pop
      @vbos[attr_idx][Mode::QUADS].pop.delete
      @bufs[attr_idx][Mode::TRIANGLES] << buf_tris
      @vbos[attr_idx][Mode::TRIANGLES] << BufferObject.new(GL::ARRAY_BUFFER)
    end

    # VAO 再作成
    vao_id = @vaos[@prim_mode].pop
    GL.DeleteVertexArrays(1, [vao_id].pack('L'))
    buf = Fiddle::Pointer.malloc(Fiddle::SIZEOF_INT)
    GL.GenVertexArrays(1, buf)
    @vaos[Mode::TRIANGLES] << buf[0, Fiddle::SIZEOF_INT].unpack1('L')

    # 現在の動作モードも QUADS -> TRIANGLES に変換して終了
    @prim_mode = Mode::TRIANGLES
  end
  private :convert_quads_to_tris


  # QUAD_STRIP -> TRIANGLE_STRIP 変換
  def convert_quad_strip_to_tri_strip
    Attribute::COUNT.times do |attr_idx|
      buf_quad_strip = @bufs[attr_idx][Mode::QUAD_STRIP].last # 矩形の頂点要素 (三角形用にコピーしたあとこれは削除)
      buf_tri_strip = [] # 三角形の頂点要素 (上記buf_quad_stripの内容を三角形用に並べなおしつつコピーするためのバッファ)
      attr_size = @@attribute_size[attr_idx]
      quad_strip_vtxs_count = (buf_quad_strip.length / attr_size)
      quad_strip_vtxs_count.times do |vi_quad_strip| # 矩形の頂点ごとに繰り返し
        # 矩形ストリップ1枚の頂点インデックス -> 三角形ストリップの頂点インデックスとなるよう変換
        # 0, 1, 2, 3, 4, 5, ... -> 1, 0, 3, 2, 5, 4, ...
        vi_tri_strip = vi_quad_strip % 2 == 0 ? vi_quad_strip + 1 : vi_quad_strip - 1
        # 矩形の頂点要素を三角形の頂点要素として詰め直す
        attr_size.times do |component_idx|
          buf_tri_strip << buf_quad_strip[vi_tri_strip*attr_size+component_idx]
        end
      end

      # Buffer/VBO 再作成
      @bufs[attr_idx][Mode::QUAD_STRIP].pop
      @vbos[attr_idx][Mode::QUAD_STRIP].pop.delete
      @bufs[attr_idx][Mode::TRIANGLE_STRIP] << buf_tri_strip
      @vbos[attr_idx][Mode::TRIANGLE_STRIP] << BufferObject.new(GL::ARRAY_BUFFER)
    end

    # VAO 再作成
    vao_id = @vaos[@prim_mode].pop
    GL.DeleteVertexArrays(1, [vao_id].pack('L'))
    buf = Fiddle::Pointer.malloc(Fiddle::SIZEOF_INT)
    GL.GenVertexArrays(1, buf)
    @vaos[Mode::TRIANGLE_STRIP] << buf[0, Fiddle::SIZEOF_INT].unpack1('L')

    # 現在の動作モードも QUAD_STRIP -> TRIANGLE_STRIP に変換して終了
    @prim_mode = Mode::TRIANGLE_STRIP
  end
  private :convert_quad_strip_to_tri_strip

end
