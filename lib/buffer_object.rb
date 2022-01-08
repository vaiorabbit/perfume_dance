require 'fiddle'
require 'opengl'

class BufferObject
  attr_reader :buffer_id, :element_count, :element_size, :buffer_target

  NullPtr = Fiddle::Pointer[0]

  # buffer_target : GL::ARRAY_BUFFER, GL::ELEMENT_ARRAY_BUFFER, etc.
  # buffer_usage  : GL::STREAM_DRAW, GL::STATIC_DRAW, GL::DYNAMIC_DRAW, etc.
  def initialize(buffer_target, buffer_usage = GL::STREAM_DRAW, element_count = 0, element_size = Fiddle::SIZEOF_FLOAT)
    @element_count = element_count
    @element_size = element_size
    @buffer_target = buffer_target

    buf = Fiddle::Pointer.malloc(Fiddle::SIZEOF_INT)
    GL.GenBuffers(1, buf)
    @buffer_id = buf[0, Fiddle::SIZEOF_INT].unpack1('L')

    GL.BindBuffer(@buffer_target, @buffer_id)
    GL.BufferData(@buffer_target, @element_count * @element_size, NullPtr, buffer_usage)
    GL.BindBuffer(@buffer_target, 0)
  end

  def delete
    GL.DeleteBuffers(1, [@buffer_id].pack('L'))
  end

  def bind
    GL.BindBuffer(@buffer_target, @buffer_id)
  end

  def unbind
    GL.BindBuffer(@buffer_target, 0)
  end

  # data_pointer : Fiddle::Pointer
  # buffer_usage : GL::STREAM_DRAW, GL::STATIC_DRAW, GL::DYNAMIC_DRAW, etc.
  def set_data(data_pointer, element_count, buffer_usage = GL::STREAM_DRAW)
    @element_count = element_count
    GL.BindBuffer(@buffer_target, @buffer_id)
    GL.BufferData(@buffer_target, @element_count * @element_size, data_pointer, buffer_usage)
    GL.BindBuffer(@buffer_target, 0)
  end

  # data_pointer : Fiddle::Pointer
  def get_data(data_pointer, element_count, offset_byte)
    GL.BindBuffer(@buffer_target, @buffer_id)
    GL.GetBufferSubData(@buffer_target, offset_byte, element_count * @element_size, data_pointer)
    GL.BindBuffer(@buffer_target, 0)
  end

  # access_mode : GL::READ_ONLY, GL::WRITE_ONLY, GL::READ_WRITE
  # return : Fiddle::Pointer
  def map(access_mode)
    GL.BindBuffer(@buffer_target, @buffer_id)
    return GL.MapBuffer(@buffer_target, access_mode)
  end

  def unmap
    GL.BindBuffer(@buffer_target, @buffer_id)
    return GL.UnmapBuffer(@buffer_target)
  end
end
