# -*- coding: utf-8 -*-
require_relative 'immediate'

class Shape

  def self.generate_circle_table(n)
    sint = nil
    cost = nil

    size = n.abs
    angle = 2 * Math::PI / n

    sint = Array.new(size + 1) { 0.0 }
    cost = Array.new(size + 1) { 0.0 }

    size.times do |i|
      sint[i] = Math.sin(angle * i)
      cost[i] = Math.cos(angle * i)
    end

    sint[size] = sint[0]
    cost[size] = cost[0]

    return sint, cost
  end


  def self.build_plane(immediate_draw, plane_width = 30.0, division_count = 10, use_checker_pattern = true, checker_color_table = [[0.2, 0.2, 0.2, 1.0], [0.7, 0.7, 0.7, 1.0]])

    checker_color_table = [[1.0, 1.0, 1.0, 1.0], [1.0, 1.0, 1.0, 1.0]] unless use_checker_pattern

    sx = -plane_width / 2.0
    sz = -plane_width / 2.0
    ex = plane_width / 2.0
    ez = plane_width / 2.0
    dx = (ex - sx) / division_count
    dz = (ez - sz) / division_count

    immediate_draw.normal3f(0.0, 1.0, 0.0)
    immediate_draw.begin_primitive(ImmediateDraw::Mode::TRIANGLE_STRIP)
    division_count.times do |nx|
      division_count.times do |nz|
        col = checker_color_table[(nx + nz) % 2]
        # Build one rectanble using two triangles; 1-0-2 and 2-1-3.
        # (the order is determined to make counter-clockwise face y-up)
        # (degenerated triangles included)
        immediate_draw.color3f(col[0], col[1], col[2])
        immediate_draw.texcoord2f(0.0, 0.0)
        immediate_draw.vertex3f(sx+nx*dx, 0.0, sz+(nz+1)*dz) # 0

        immediate_draw.color3f(col[0], col[1], col[2])
        immediate_draw.texcoord2f(0.0, 0.0)
        immediate_draw.vertex3f(sx+nx*dx, 0.0, sz+(nz+1)*dz) # 0

        immediate_draw.color3f(col[0], col[1], col[2])
        immediate_draw.texcoord2f(1.0, 0.0)
        immediate_draw.vertex3f(sx+nx*dx, 0.0, sz+nz*dz) # 1

        immediate_draw.color3f(col[0], col[1], col[2])
        immediate_draw.texcoord2f(0.0, 1.0)
        immediate_draw.vertex3f(sx+(nx+1)*dx, 0.0, sz+(nz+1)*dz) # 2

        immediate_draw.color3f(col[0], col[1], col[2])
        immediate_draw.texcoord2f(1.0, 1.0)
        immediate_draw.vertex3f(sx+(nx+1)*dx, 0.0, sz+nz*dz) # 3

        immediate_draw.color3f(col[0], col[1], col[2])
        immediate_draw.texcoord2f(1.0, 1.0)
        immediate_draw.vertex3f(sx+(nx+1)*dx, 0.0, sz+nz*dz) # 3

=begin
        immediate_draw.color3f(col[0], col[1], col[2])
        immediate_draw.texcoord2f(1.0, 0.0)
        immediate_draw.vertex3f(sx+nx*dx, 0.0, sz+nz*dz) # 0

        immediate_draw.color3f(col[0], col[1], col[2])
        immediate_draw.texcoord2f(1.0, 0.0)
        immediate_draw.vertex3f(sx+nx*dx, 0.0, sz+nz*dz) # 0

        immediate_draw.color3f(col[0], col[1], col[2])
        immediate_draw.texcoord2f(0.0, 0.0)
        immediate_draw.vertex3f(sx+nx*dx, 0.0, sz+(nz+1)*dz) # 1

        immediate_draw.color3f(col[0], col[1], col[2])
        immediate_draw.texcoord2f(1.0, 1.0)
        immediate_draw.vertex3f(sx+(nx+1)*dx, 0.0, sz+nz*dz) # 2

        immediate_draw.color3f(col[0], col[1], col[2])
        immediate_draw.texcoord2f(0.0, 1.0)
        immediate_draw.vertex3f(sx+(nx+1)*dx, 0.0, sz+(nz+1)*dz) # 3

        immediate_draw.color3f(col[0], col[1], col[2])
        immediate_draw.texcoord2f(0.0, 1.0)
        immediate_draw.vertex3f(sx+(nx+1)*dx, 0.0, sz+(nz+1)*dz) # 3
=end
      end
    end

    immediate_draw.end_primitive()
  end

  def self.build_sphere(immediate_draw, radius = 1.0, slices = 36, stacks = 36, color = [1.0, 1.0, 1.0, 1.0])
    # stacks : Z軸方向分割数, slices : Z軸回転の分割数

    # 三角関数をテーブル化
    sint1, cost1 = generate_circle_table(-slices) # '-' : Z軸左回り
    sint2, cost2 = generate_circle_table(stacks)

    # 上端・下端 : 極を頂点とする TRIANGLE_FAN で構成
    immediate_draw.color4f(color[0], color[1], color[2], color[3])
    immediate_draw.texcoord2f(0.0, 0.0)
    immediate_draw.begin_primitive(ImmediateDraw::Mode::TRIANGLE_FAN)

    z1 = cost2[1]
    r1 = sint2[1]
    immediate_draw.normal3f(0.0, 0.0, 1.0)
    immediate_draw.vertex3f(0.0, 0.0, radius)
    slices.downto(0) do |j|
      immediate_draw.normal3f(cost1[j] * r1,          sint1[j] * r1,          z1         )
      immediate_draw.vertex3f(cost1[j] * r1 * radius, sint1[j] * r1 * radius, z1 * radius)
    end

    z0 = cost2[stacks-1]
    r0 = sint2[stacks-1]
    immediate_draw.normal3f(0.0, 0.0, -1.0)
    immediate_draw.vertex3f(0.0, 0.0, -radius)
    (0..slices).each do |j|
      immediate_draw.normal3f(cost1[j] * r0,          sint1[j] * r0,          z0        )
      immediate_draw.vertex3f(cost1[j] * r0 * radius, sint1[j] * r0 * radius, z0 * radius)
    end
    immediate_draw.end_primitive()

    # 上端・下端を除く側面はZ軸正方向から順に帯で構成
    (1...stacks-1).each do |i|
      z0, z1 = cost2[i], cost2[i+1]
      r0, r1 = sint2[i], sint2[i+1]
      immediate_draw.begin_primitive(ImmediateDraw::Mode::QUAD_STRIP)
      (slices+1).times do |j|
        immediate_draw.normal3f(cost1[j] * r1,          sint1[j] * r1,          z1         )
        immediate_draw.vertex3f(cost1[j] * r1 * radius, sint1[j] * r1 * radius, z1 * radius)

        immediate_draw.normal3f(cost1[j] * r0,          sint1[j] * r0,          z0         )
        immediate_draw.vertex3f(cost1[j] * r0 * radius, sint1[j] * r0 * radius, z0 * radius)
      end
      immediate_draw.end_primitive()
    end
  end

  def self.build_cube(immediate_draw, size = 1.0, color = [1.0, 1.0, 1.0, 1.0])
    s = size / 2
    immediate_draw.color3f(1.0, 1.0, 1.0)
    immediate_draw.begin_primitive(ImmediateDraw::Mode::QUADS)
    immediate_draw.normal3f(1.0, 0.0, 0.0)
    immediate_draw.texcoord2f(0.0, 1.0); immediate_draw.vertex3f(+s,-s,+s)
    immediate_draw.texcoord2f(1.0, 1.0); immediate_draw.vertex3f(+s,-s,-s)
    immediate_draw.texcoord2f(1.0, 0.0); immediate_draw.vertex3f(+s,+s,-s)
    immediate_draw.texcoord2f(0.0, 0.0); immediate_draw.vertex3f(+s,+s,+s)

    immediate_draw.normal3f(0.0, 1.0, 0.0)
    immediate_draw.texcoord2f(1.0, 1.0); immediate_draw.vertex3f(+s,+s,+s)
    immediate_draw.texcoord2f(1.0, 0.0); immediate_draw.vertex3f(+s,+s,-s)
    immediate_draw.texcoord2f(0.0, 0.0); immediate_draw.vertex3f(-s,+s,-s)
    immediate_draw.texcoord2f(0.0, 1.0); immediate_draw.vertex3f(-s,+s,+s)

    immediate_draw.normal3f(0.0, 0.0, 1.0)
    immediate_draw.texcoord2f(1.0, 0.0); immediate_draw.vertex3f(+s,+s,+s)
    immediate_draw.texcoord2f(0.0, 0.0); immediate_draw.vertex3f(-s,+s,+s)
    immediate_draw.texcoord2f(0.0, 1.0); immediate_draw.vertex3f(-s,-s,+s)
    immediate_draw.texcoord2f(1.0, 1.0); immediate_draw.vertex3f(+s,-s,+s)

    immediate_draw.normal3f(-1.0, 0.0, 0.0)
    immediate_draw.texcoord2f(1.0, 1.0); immediate_draw.vertex3f(-s,-s,+s)
    immediate_draw.texcoord2f(1.0, 0.0); immediate_draw.vertex3f(-s,+s,+s)
    immediate_draw.texcoord2f(0.0, 0.0); immediate_draw.vertex3f(-s,+s,-s)
    immediate_draw.texcoord2f(0.0, 1.0); immediate_draw.vertex3f(-s,-s,-s)

    immediate_draw.normal3f(0.0, -1.0, 0.0)
    immediate_draw.texcoord2f(0.0, 0.0); immediate_draw.vertex3f(-s,-s,+s)
    immediate_draw.texcoord2f(0.0, 1.0); immediate_draw.vertex3f(-s,-s,-s)
    immediate_draw.texcoord2f(1.0, 1.0); immediate_draw.vertex3f(+s,-s,-s)
    immediate_draw.texcoord2f(1.0, 0.0); immediate_draw.vertex3f(+s,-s,+s)

    immediate_draw.normal3f(0.0, 0.0, -1.0)
    immediate_draw.texcoord2f(1.0, 1.0); immediate_draw.vertex3f(-s,-s,-s)
    immediate_draw.texcoord2f(1.0, 0.0); immediate_draw.vertex3f(-s,+s,-s)
    immediate_draw.texcoord2f(0.0, 0.0); immediate_draw.vertex3f(+s,+s,-s)
    immediate_draw.texcoord2f(0.0, 1.0); immediate_draw.vertex3f(+s,-s,-s)

    immediate_draw.end_primitive()
  end

  def self.build_torus(immediate_draw, in_radius = 0.5, out_radius = 1.0, sides = 36, rings = 36, color = [1.0, 1.0, 1.0, 1.0])
    sides += 1
    rings += 1

    vertex = Array.new(3 * sides * rings) { 0.0 }
    normal = Array.new(3 * sides * rings) { 0.0 }

    delta_psi =  2.0 * Math::PI / (rings - 1).to_f
    delta_phi = -2.0 * Math::PI / (sides - 1).to_f
    psi = 0.0

    rings.times do |j|
      cpsi = Math.cos(psi)
      spsi = Math.sin(psi)
      phi = 0.0

      sides.times do |i|
        offset = 3 * (j * sides + i)
        cphi = Math.cos(phi)
        sphi = Math.sin(phi)
        vertex[offset + 0] = cpsi * (out_radius + cphi * in_radius)
        vertex[offset + 1] = spsi * (out_radius + cphi * in_radius)
        vertex[offset + 2] =                      sphi * in_radius
        normal[offset + 0] = cpsi * cphi
        normal[offset + 1] = spsi * cphi
        normal[offset + 2] =        sphi
        phi += delta_phi
      end
      psi += delta_psi
    end

    immediate_draw.color4f(color[0], color[1], color[2], color[3])
    immediate_draw.texcoord2f(0.0, 0.0)
    immediate_draw.begin_primitive(ImmediateDraw::Mode::QUADS)
    (sides-1).times do |i|
      (rings-1).times do |j|
        offset = 3 * (j * sides + i)
        immediate_draw.normal3f(normal[offset + 0], normal[offset + 1], normal[offset + 2])
        immediate_draw.vertex3f(vertex[offset + 0], vertex[offset + 1], vertex[offset + 2])
        immediate_draw.normal3f(normal[(offset+3) + 0], normal[(offset+3) + 1], normal[(offset+3) + 2])
        immediate_draw.vertex3f(vertex[(offset+3) + 0], vertex[(offset+3) + 1], vertex[(offset+3) + 2])
        immediate_draw.normal3f(normal[(offset+3*sides+3) + 0], normal[(offset+3*sides+3) + 1], normal[(offset+3*sides+3) + 2])
        immediate_draw.vertex3f(vertex[(offset+3*sides+3) + 0], vertex[(offset+3*sides+3) + 1], vertex[(offset+3*sides+3) + 2])
        immediate_draw.normal3f(normal[(offset+3*sides) + 0], normal[(offset+3*sides) + 1], normal[(offset+3*sides) + 2])
        immediate_draw.vertex3f(vertex[(offset+3*sides) + 0], vertex[(offset+3*sides) + 1], vertex[(offset+3*sides) + 2])
      end
    end
    immediate_draw.end_primitive()
  end

  def self.build_bone(immediate_draw, length = 1.0, radius_minor = length / 10.0, hw = radius_minor, color = [0.8, 0.8, 1.0, 1.0])

    radius_major = length - radius_minor

    # minor axis
    immediate_draw.color4f(color[0], color[1], color[2], color[3])
    immediate_draw.texcoord2f(0.0, 0.0)

    immediate_draw.begin_primitive(ImmediateDraw::Mode::TRIANGLE_FAN)

    immediate_draw.normal3f(-1.0, 0.0, 0.0)
    immediate_draw.vertex3f(0.0, 0.0, 0.0)

    immediate_draw.normal3f(0.0, 1.0, 0.0)
    immediate_draw.vertex3f(radius_minor, hw, 0.0)
    immediate_draw.normal3f(0.0, 0.0, -1.0)
    immediate_draw.vertex3f(radius_minor, 0.0, -hw)
    immediate_draw.normal3f(0.0, -1.0, 0.0)
    immediate_draw.vertex3f(radius_minor, -hw, 0.0)
    immediate_draw.normal3f(0.0, 0.0, 1.0)
    immediate_draw.vertex3f(radius_minor, 0.0,  hw)
    immediate_draw.normal3f(0.0, 1.0, 0.0)
    immediate_draw.vertex3f(radius_minor, hw, 0.0)
    immediate_draw.end_primitive()

    # major axis
    immediate_draw.color4f(color[0], color[1], color[2], color[3])
    immediate_draw.texcoord2f(0.0, 0.0)

    immediate_draw.begin_primitive(ImmediateDraw::Mode::TRIANGLE_FAN)

    immediate_draw.normal3f(1.0, 0.0, 0.0)
    immediate_draw.vertex3f(length, 0.0, 0.0)

    immediate_draw.normal3f(0.0, 1.0, 0.0)
    immediate_draw.vertex3f(radius_minor, hw, 0.0)

    immediate_draw.normal3f(0.0, 0.0, 1.0)
    immediate_draw.vertex3f(radius_minor, 0.0,  hw)

    immediate_draw.normal3f(0.0, -1.0, 0.0)
    immediate_draw.vertex3f(radius_minor, -hw, 0.0)

    immediate_draw.normal3f(0.0, 0.0, -1.0)
    immediate_draw.vertex3f(radius_minor, 0.0, -hw)

    immediate_draw.normal3f(0.0, 1.0, 0.0)
    immediate_draw.vertex3f(radius_minor, hw, 0.0)

    immediate_draw.end_primitive()
  end

end
