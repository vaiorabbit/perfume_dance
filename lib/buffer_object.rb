require 'fiddle'
require 'opengl'
include OpenGL

class BufferObject
  attr_reader :buffer_id, :element_count, :element_size, :buffer_target

  NullPtr = Fiddle::Pointer[0]

  # buffer_target : GL_ARRAY_BUFFER, GL_ELEMENT_ARRAY_BUFFER, etc.
  # buffer_usage  : GL_STREAM_DRAW, GL_STATIC_DRAW, GL_DYNAMIC_DRAW, etc.
  def initialize( buffer_target, buffer_usage = GL_STREAM_DRAW, element_count = 0, element_size = Fiddle::SIZEOF_FLOAT )
    @element_count = element_count
    @element_size = element_size
    @buffer_target = buffer_target

    buf = Fiddle::Pointer.malloc(Fiddle::SIZEOF_INT)
    glGenBuffers(1, buf)
    @buffer_id = buf[0, Fiddle::SIZEOF_INT].unpack('L')[0]

    glBindBuffer(@buffer_target, @buffer_id)
    glBufferData(@buffer_target, @element_count * @element_size, NullPtr, buffer_usage)
    glBindBuffer(@buffer_target, 0)
  end

  def delete
    glDeleteBuffers(1, [@buffer_id].pack('L'))
  end

  def bind
    glBindBuffer(@buffer_target, @buffer_id)
  end

  def unbind
    glBindBuffer(@buffer_target, 0)
  end

  # data_pointer : Fiddle::Pointer
  # buffer_usage : GL_STREAM_DRAW, GL_STATIC_DRAW, GL_DYNAMIC_DRAW, etc.
  def set_data( data_pointer, element_count, buffer_usage = GL_STREAM_DRAW )
    @element_count = element_count
    glBindBuffer(@buffer_target, @buffer_id)
    glBufferData(@buffer_target, @element_count * @element_size, data_pointer, buffer_usage)
    glBindBuffer(@buffer_target, 0)
  end

  # data_pointer : Fiddle::Pointer
  def get_data( data_pointer, element_count, offset_byte )
    glBindBuffer(@buffer_target, @buffer_id)
    glGetBufferSubData(@buffer_target, offset_byte, element_count * @element_size, data_pointer)
    glBindBuffer(@buffer_target, 0)
  end

  # access_mode : GL_READ_ONLY, GL_WRITE_ONLY, GL_READ_WRITE
  # return : Fiddle::Pointer
  def map( access_mode )
    glBindBuffer(@buffer_target, @buffer_id)
    return glMapBuffer(@buffer_target, access_mode)
  end

  def unmap
    glBindBuffer(@buffer_target, @buffer_id)
    return glUnmapBuffer(@buffer_target)
  end
end
