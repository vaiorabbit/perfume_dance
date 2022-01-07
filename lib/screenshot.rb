require 'opengl'
require 'fiddle'
require_relative 'utils'

class ScreenShotSession
  def initialize(width, height, depth, path="./tmp")
    @width = width
    @height = height
    @depth = depth
    @path = path

    @count = 0
    @session_name = ""

    @buffer = Fiddle::Pointer.malloc(Fiddle::SIZEOF_CHAR * @width * @height * @depth)

    update_session_name()
  end

  def save()
    GL.ReadPixels(0, 0, @width, @height,
                  GL::BGRA, GL::UNSIGNED_INT_8_8_8_8_REV, @buffer)
    filename = @session_name + sprintf("_ID%05d.tga", @count)
    File.open(@path + '/' + filename, 'wb') do |fout|
      fout.write [0].pack('c')           # identsize
      fout.write [0].pack('c')           # colourmaptype
      fout.write [2].pack('c')           # imagetype
      fout.write [0].pack('s')           # colourmapstart
      fout.write [0].pack('s')           # colourmaplength
      fout.write [0].pack('c')           # colourmapbits
      fout.write [0].pack('s')           # xstart
      fout.write [0].pack('s')           # ystart
      fout.write [@width].pack('s')      # image_width
      fout.write [@height].pack('s')     # image_height
      fout.write [@depth * 4].pack('c')  # image_bits_per_pixel
      fout.write [8].pack('c')           # descriptor

      fout.write @buffer[0, @buffer.size]
      @count += 1
    end
  end

  def reset(width, height, depth)
  end

  def update_session_name()
    tm = Time.now
    @session_name = sprintf("ScreenShot_%4d%02d%02d%02d%02d%02d", tm.year, tm.month, tm.mday, tm.hour, tm.min, tm.sec)
  end
  private :update_session_name
end
