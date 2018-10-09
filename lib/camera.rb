# -*- coding: utf-8 -*-

class SphericalCoordCamera

  attr_reader :width, :height, :fovy_deg, :position
  attr_accessor :radius, :radius_min, :radius_max, :at, :z_near, :z_far

  def initialize( phi = Math::PI/2.0, theta = Math::PI/3.0, radius = 20.0, radius_min = 5.0, radius_max = 30.0 )
    @mouse_state = 0
    @prev_x = 0
    @prev_y = 0
    @phi = phi
    @theta = theta
    @radius = radius
    @radius_min = radius_min
    @radius_max = radius_max

    wrap_params()

    @position = RVec3.new( @radius * Math.sin(@theta) * Math.cos(@phi), @radius * Math.cos(@theta), @radius * Math.sin(@theta) * Math.sin(@phi) )
    @at       = RVec3.new( 0, 0, 0 )
    @up       = RVec3.new( 0, 1, 0 )

    @mtxView = RMtx4.new.lookAtRH( @position, @at, @up )

    @width    = 640
    @height   = 340
    @fovy_deg = 30.0
    @z_near   = 0.1
    @z_far    = 200.0

    @mtxProj = RMtx4.new.perspectiveFovRH( Math::PI * @fovy_deg / 180.0, @width.to_f/@height.to_f, @z_near, @z_far )

    @mtxPVInv = RMtx4.new.setIdentity

    @renew_view = true
    @renew_proj = true
    @renew_pvinv = true
  end

  def width= ( w )
    return if @width == w
    @width = w
    @renew_proj = true
    @renew_pvinv = true
  end

  def height= ( h )
    return if @height == h
    @height = h
    @renew_proj = true
    @renew_pvinv = true
  end

  def set_mouse_state( button, state, x, y )
    if button == GLFW_MOUSE_BUTTON_LEFT
      if state == GLFW_PRESS
        @mouse_state |= 1
      else # GLFW_RELEASE
        @mouse_state &= ~1
      end
    end
    if button == GLFW_MOUSE_BUTTON_RIGHT
      if state == GLFW_PRESS
        @mouse_state |= 2
      else # GLFW_RELEASE
        @mouse_state &= ~2
      end
    end
    if button == GLFW_MOUSE_BUTTON_MIDDLE
      if state == GLFW_PRESS
        @mouse_state |= 4
      else # GLFW_RELEASE
        @mouse_state &= ~4
      end
    end
    @prev_x = x
    @prev_y = y
  end


  def update_from_mouse_motion( x, y )
    if @mouse_state != 0
      dx = ( x - @prev_x ).to_f
      dy = ( y - @prev_y ).to_f

      if @mouse_state == 1 # Left
        scale = 0.5
        @phi += scale * dx * Math::PI/180
        @theta -= scale * dy * Math::PI/180
      elsif @mouse_state == 2 # Right
        scale = 0.5
        @radius -= scale * dy
      end

      wrap_params()
      @position.x = @radius * Math.sin(@theta) * Math.cos(@phi)
      @position.z = @radius * Math.sin(@theta) * Math.sin(@phi)
      @position.y = @radius * Math.cos(@theta)

      @renew_view = true
      @renew_pvinv = true
    end

    @prev_x = x
    @prev_y = y
  end


  def wrap_params
    @phi -= 2*Math::PI if @phi > 2*Math::PI
    @phi += 2*Math::PI if @phi < -2*Math::PI

    @theta = Math::PI/2 if @theta > Math::PI/2
    @theta = RMath3D::TOLERANCE if @theta < RMath3D::TOLERANCE

    @radius = @radius_max if @radius > @radius_max
    @radius = @radius_min if @radius < @radius_min
  end


  def get_view_matrix
    if @renew_view
      @renew_view = false
      @mtxView.lookAtRH( @position, @at, @up )
    end
    return @mtxView
  end


  def get_projection_matrix
    if @renew_proj
      @renew_proj = false
      @mtxProj.perspectiveFovRH( Math::PI * @fovy_deg / 180.0, @width.to_f/@height.to_f, @z_near, @z_far )
    end
    return @mtxProj
  end

  def get_mtxPVInv
    if @renew_pvinv
      @renew_pvinv = false
      @mtxPVInv = (get_projection_matrix * get_view_matrix).invert!
    end
    return @mtxPVInv
  end

  # Ref.: http://www.opengl.org/wiki/GluProject_and_gluUnProject_code
  def unproject( win_x, win_y, win_z )
    v= RVec4.new( 2.0 * (win_x - @width) / @width.to_f + 1.0,
                  2.0 * (@height - win_y) / @height.to_f - 1.0,
                  win_z,
                  1.0 )
    v.transform!( get_mtxPVInv )
    return RVec3.new( v.x/v.w, v.y/v.w, v.z/v.w )
  end

  def get_pick_ray( win_x, win_y )
    ray_orig = unproject( win_x, win_y, -1.0 )
    ray_dest = unproject( win_x, win_y,  1.0 )
    ray_dir = (ray_dest - ray_orig).normalize!
    return ray_orig, ray_dir
  end

end # class SphericalCoordCamera
