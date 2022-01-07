def check_errors(desc)
  e = GL.GetError()
  if e != GL::NO_ERROR
    $stderr.printf "OpenGL error in \"#{desc}\": e=0x%08x\n", e.to_i
    exit
  end
end
