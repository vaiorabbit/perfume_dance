# -*- coding: utf-8 -*-
begin
  if Gem::Specification::find_by_name('rmath3d')
    require 'rmath3d/rmath3d'
  end
rescue Gem::LoadError
  require 'rmath3d/rmath3d_plain'
end
include RMath3D

require 'opengl'
require 'glfw'
require_relative './lib/utils'
require_relative './lib/camera'
require_relative './lib/immediate'
require_relative './lib/shape'
require_relative './lib/motion'
require_relative './lib/screenshot'

OpenGL.load_lib()
GLFW.load_lib()

include OpenGL
include GLFW

$camera = nil
$screenshot = nil

$height = 85.0

# Press ESC to exit.
key_callback = GLFW::create_callback(:GLFWkeyfun) do |window_handle, key, scancode, action, mods|
  if key == GLFW_KEY_ESCAPE && action == GLFW_PRESS
    glfwSetWindowShouldClose(window_handle, 1)
  end
end

size_callback = GLFW::create_callback( :GLFWwindowsizefun ) do|window_handle, w, h|
  $camera.width = w
  $camera.height = h
  glViewport(0, 0, w, h)
end

mousebutton_callback = GLFW::create_callback(:GLFWmousebuttonfun) do |window_handle, button, action, mods|
  x_buf = '        '
  y_buf = '        '
  glfwGetCursorPos(window_handle, x_buf, y_buf)
  x = x_buf.unpack('D')[0]
  y = y_buf.unpack('D')[0]

  $camera.set_mouse_state( button, action, x, y )
end

cursorpos_callback = GLFW::create_callback(:GLFWcursorposfun) do |window_handle, x, y|
  $camera.update_from_mouse_motion( x, y )
end


if __FILE__ == $0
  glfwInit()
#  glfwDefaultWindowHints()
#  glfwWindowHint(GLFW_CONTEXT_VERSION_MAJOR, 3)
#  glfwWindowHint(GLFW_CONTEXT_VERSION_MINOR, 3)
#  glfwWindowHint(GLFW_SAMPLES, 8)

  w = 720.0
  h = 405.0
  window = nil

  versions = [[4, 5], [4, 4], [4, 3], [4, 2], [4, 1], [4, 0],
              [3, 3], [3, 2], [3, 1], [3, 0],
              [2, 1], [2, 0],
              [1, 5], [1, 4], [1, 3], [1, 2], [1, 1], [1, 0]]
  versions.each do |version|
    ver_major = version[0]
    ver_minor = version[1]
    glfwDefaultWindowHints()
    if OpenGL.get_platform == :OPENGL_PLATFORM_MACOSX
      glfwWindowHint(GLFW_OPENGL_FORWARD_COMPAT, GL_TRUE)
    end
    if ver_major >= 4 || (ver_major >= 3 && ver_minor >= 2)
      glfwWindowHint(GLFW_OPENGL_PROFILE, GLFW_OPENGL_CORE_PROFILE)
    else
      glfwWindowHint(GLFW_OPENGL_PROFILE, GLFW_OPENGL_ANY_PROFILE)
    end
    glfwWindowHint(GLFW_CONTEXT_VERSION_MAJOR, ver_major)
    glfwWindowHint(GLFW_CONTEXT_VERSION_MINOR, ver_minor)
    window = glfwCreateWindow( w, h, "Motion Parser", nil, nil )
    break unless window.null?
  end

  exit if window.null?

  glfwMakeContextCurrent( window )
  glfwSetKeyCallback( window, key_callback )

  glfwSetWindowSizeCallback( window, size_callback )
  glfwSetMouseButtonCallback( window, mousebutton_callback )
  glfwSetCursorPosCallback( window, cursorpos_callback )

  glClearColor(0.6, 0.6, 0.8, 0.0)

  glEnable(GL_BLEND)
  glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA)
  glEnable(GL_DEPTH_TEST)
  glDepthFunc(GL_LEQUAL)

  #$camera = SphericalCoordCamera.new( Math::PI/2.0, Math::PI/3.0, 200.0, 200.0, 20000.0 )
  $camera = SphericalCoordCamera.new( 3.953170755767155, 1.2304571226560024, 720.0, 200.0, 20000.0 )
  $camera.width = w
  $camera.height = h
  $camera.radius_min = 20.0
  $camera.radius_max = 20000.0
  $camera.at.setElements( 0.0, $height, 0.0 )
  $camera.z_far = 30000.0

  $screenshot = ScreenShotSession.new( 720, 405, 8 )

  mtx_model = RMtx4.new.setIdentity

  width_ptr = '        '
  height_ptr = '        '
  glfwGetFramebufferSize(window, width_ptr, height_ptr)
  width = width_ptr.unpack('L')[0]
  height = height_ptr.unpack('L')[0]
  size_callback.call( window, width, height )

  ImmediateDraw.setup
  im_plane = ImmediateDraw.new
  im_sphere = ImmediateDraw.new
  im_bone = Array.new(3)
  im_bone[0] = ImmediateDraw.new
  im_bone[1] = ImmediateDraw.new
  im_bone[2] = ImmediateDraw.new

  # for glPolygonMode GL_POINT
  # glPointSize(5.0)
  # for TRIANGLES, TRIANGLE_STRIP
  glEnable(GL_CULL_FACE)
  glFrontFace(GL_CCW)

  # glPolygonMode( GL_FRONT_AND_BACK, GL_LINE )
  # glPolygonMode( GL_FRONT_AND_BACK, GL_POINT )

  im_plane.set_light_position( 100.0, 100.0, 100.0 )
  im_plane.set_use_lighting( false )
  im_plane.set_use_texture( false )

  im_bone.length.times do |i|
    im_bone[i].set_light_position( 100.0, 100.0, 100.0 )
    im_bone[i].set_use_lighting( false )
    im_bone[i].set_use_texture( false )
  end

  im_sphere.set_light_position( 100.0, 100.0, 100.0 )
  im_sphere.set_use_lighting( false )
  im_sphere.set_use_texture( false )

  Shape.build_plane( im_plane, 1000.0 ) # Floor
  Shape.build_bone( im_bone[0], 1.0, 0.15, 2.0, [0.2, 0.2, 1.0, 1.0] ) # Bone (Blue)
  Shape.build_bone( im_bone[1], 1.0, 0.15, 2.0, [1.0, 0.2, 0.2, 1.0] ) # Bone (Red)
  Shape.build_bone( im_bone[2], 1.0, 0.15, 2.0, [0.2, 1.0, 0.2, 1.0] ) # Bone (Green)
  Shape.build_sphere( im_sphere, 1.0, 18, 18, [1.0, 1.0, 0.0, 1.0] ) # Joint (Yellow)

  root_node = Array.new(3)
  motion_data = Array.new(3)
  skeleton = Array.new(3)
  bvh = File.new( './data/aachan.bvh' )
  root_node[0], motion_data[0] = BVHFormat.parse( bvh )
  skeleton[0] = Motion::Skeleton.new( root_node[0] )

  bvh = File.new( './data/kashiyuka.bvh' )
  root_node[1], motion_data[1] = BVHFormat.parse( bvh )
  skeleton[1] = Motion::Skeleton.new( root_node[1] )

  bvh = File.new( './data/nocchi.bvh' )
  root_node[2], motion_data[2] = BVHFormat.parse( bvh )
  skeleton[2] = Motion::Skeleton.new( root_node[2] )

  # skeleton.joints.each do |j|
  #   p j.name
  # end

  pr = 20.0
  px = pr
  pz = 0.0
  rq = RQuat.new.setIdentity

  frame = 1

  time_accum = 0.0
  time_prev = 0.0
  time_start = Time.now
  while glfwWindowShouldClose( window ) == 0
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT)

    mtx_model.translation( 0.0, 0.0, 0.0 )
    mtx_view = $camera.get_view_matrix
    mtx_proj = $camera.get_projection_matrix
    mtx_MVP = mtx_proj * mtx_view * mtx_model

    im_plane.set_matrix(mtx_model, mtx_view, mtx_proj)
    im_plane.draw()

    im_sphere.set_matrix(mtx_model, mtx_view, mtx_proj)
    im_bone.length.times do |i|
      im_bone[i].set_matrix(mtx_model, mtx_view, mtx_proj)
    end
    skeleton.length.times do |i|
      skeleton[i].set_pose( motion_data[i], frame )
      skeleton[i].draw_skeleton( im_bone[i], im_sphere )
    end
    time_now = Time.now
    time_accum += (time_now - time_prev).to_f
    time_prev = time_now

    # px = pr * Math.cos(time_accum)
    # pz = pr * Math.sin(time_accum)
    # rq.rotationAxis( RVec3.new(0,1,0), -time_accum)

    # $screenshot.save

    glfwSwapBuffers( window )
    glfwPollEvents()

    frame += 1
    frame = 0 if frame >= motion_data[0].frame_count

    # if time_now - time_start > 10
    #   GC.start
    #   p GC.stat
    #   time_start = time_now
    # end
  end

  im_plane.delete
  ImmediateDraw.release

  glfwDestroyWindow( window )
  glfwTerminate()
end
