def check_errors( desc )
  e = glGetError()
  if e != GL_NO_ERROR
    $stderr.printf "OpenGL error in \"#{desc}\": e=0x%08x\n", e.to_i
    exit
  end
end
