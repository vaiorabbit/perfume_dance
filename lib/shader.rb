require_relative 'utils'
require 'opengl'

class Shader

  attr_reader :program_id

  def initialize
    @program_id = GL.CreateProgram()
  end

  def compile(type, code)
    shader_id = GL.CreateShader(type)
    srcs = [code].pack('p')
    lens = [code.length].pack('I')
    GL.ShaderSource(shader_id, 1, srcs, lens)
    GL.CompileShader(shader_id)

    result_buf = '    '
    GL.GetShaderiv(shader_id, GL::COMPILE_STATUS, result_buf)
    result = result_buf.unpack1('L') # GLint

    if result == GL::FALSE
      log_length_buf = '    '
      GL.GetShaderiv(shader_id, GL::INFO_LOG_LENGTH, log_length_buf)
      log_length = log_length_buf.unpack1('L')
      log = ' ' * log_length
      GL.GetShaderInfoLog(shader_id, log_length, nil, log)
      puts log
      return -1
    end

    return shader_id
  end
  private :compile

  def load(vertex_code: nil, fragment_code: nil)
    shader_ids = []

    # Compile each shader
    if vertex_code != nil
      id = compile(GL::VERTEX_SHADER, vertex_code)
      shader_ids << id
    end
    if fragment_code != nil
      id = compile(GL::FRAGMENT_SHADER, fragment_code)
      shader_ids << id
    end

    # Link shaders into one program
    shader_ids.each do |shader_id|
      GL.AttachShader(@program_id, shader_id)
    end
    GL.LinkProgram(@program_id)

    result_buf = '    '
    GL.GetProgramiv(@program_id, GL::LINK_STATUS, result_buf)
    result = result_buf.unpack1('L') # GLint

    if result == GL::FALSE
      log_length_buf = '    '
      GL.GetProgramiv(@program_id, GL::INFO_LOG_LENGTH, log_length_buf)
      log_length = log_length_buf.unpack1('L')
      log = ' ' * log_length
      GL.GetProgramInfoLog(@program_id, log_length, nil, log)
      puts log
      return -1
    end

    shader_ids.each do |shader_id|
      GL.DeleteShader(shader_id)
    end
    return @program_id
  end

  def delete
    GL.DeleteProgram(@program_id)
  end

  def use
    GL.UseProgram(@program_id)
  end

  def unuse
    GL.UseProgram(0)
  end

  def location(name)
    return GL.GetUniformLocation(@program_id, name)
  end

  def set_uniform(name, *args)
    loc = location(name)
    if loc < 0 # optimized out or misspell. Ref.: http://www.opengl.org/wiki/GLSL_:_common_mistakes
      print "Shader#set_uniform : Location for \"#{name}\" not found. Arg0 Class:#{args[0].class}, Length:#{args.length}\n"
      # return
    end
    case args[0]
    when Fixnum
      case args.length
      when 1; GL.Uniform1i(loc, args[0])
      when 2; GL.Uniform2i(loc, args[0], args[1])
      when 3; GL.Uniform3i(loc, args[0], args[1], args[2])
      when 4; GL.Uniform4i(loc, args[0], args[1], args[2], args[3])
      end
    when Float
      case args.length
      when 1; GL.Uniform1f(loc, args[0])
      when 2; GL.Uniform2f(loc, args[0], args[1])
      when 3; GL.Uniform3f(loc, args[0], args[1], args[2])
      when 4; GL.Uniform4f(loc, args[0], args[1], args[2], args[3])
      end
    when RVec3; GL.Uniform3f(loc, args[0].x, args[0].y, args[0].z)
    when RVec4; GL.Uniform4f(loc, args[0].x, args[0].y, args[0].z, args[0].w)
    when RMtx3; GL.UniformMatrix3fv(loc, 1, GL::FALSE, args[0].to_a.pack('F*'))
    when RMtx4; GL.UniformMatrix4fv(loc, 1, GL::FALSE, args[0].to_a.pack('F*'))
    end
  end

end
