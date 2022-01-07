require_relative 'immediate'

module Motion

  XAxis = RVec3.new(1.0, 0.0, 0.0)
  ZAxis = RVec3.new(0.0, 0.0, 1.0)

  class Skeleton

    attr_reader :joints

    def initialize(root_joint)
      @root_joint = root_joint
      @joints = []
      add_joint(@root_joint)
    end

    def add_joint(joint)
      @joints << joint
      joint.children.each do |child|
        add_joint(child)
      end
    end
    private :add_joint

    def find_joint_index(name)
      return @joints.index { |joint| joint.name == name }
    end

    def get_joint(index)
      return @joints[index]
    end

    def get_joint_count()
      return @joints.length
    end

    def set_position(x, y, z)
      @root_joint.set_position(x, y, z)
    end

    def set_rotation(q)
      @root_joint.set_rotation(q)
    end

    def draw_skeleton_recursive(joint, mtx_accum, depth, im_bone, im_sphere)
      mtx_current = mtx_accum * joint.local_transform
      im_sphere.set_model_matrix(mtx_current)
      im_sphere.draw

      joint.children.each do |child|
        im_bone.set_model_matrix(mtx_current * child.mtx_bone_rotation * child.mtx_bone_scale)
        im_bone.draw
        draw_skeleton_recursive(child, mtx_current, depth+1, im_bone, im_sphere)
      end
    end
    private :draw_skeleton_recursive

    def draw_skeleton(im_bone, im_sphere)
      mtx_root = @root_joint.local_transform
      im_sphere.set_model_matrix(mtx_root)
      im_sphere.draw

      @root_joint.children.each do |child|
        im_bone.set_model_matrix(mtx_root * child.mtx_bone_rotation * child.mtx_bone_scale)
        im_bone.draw
        draw_skeleton_recursive(child, mtx_root, 1, im_bone, im_sphere)
      end
    end

    def set_pose(motion_data, frame)
      return if motion_data.joint_count != get_joint_count()

      pos = motion_data.get_position(frame)
      set_position(pos.x, pos.y, pos.z)

      motion_data.joint_count.times do |joint_index|
        get_joint(joint_index).set_rotation(motion_data.get_rotation(frame, joint_index))
      end
    end

  end # class Skeleton

  class Joint
    attr_accessor :name, :parent, :children, :rotation, :position, :default_transform
    attr_reader :offset, :mtx_offset, :mtx_bone_rotation, :mtx_bone_scale
    def initialize(parent, name = "")
      @name = name

      # Tree structure
      @parent = parent
      @children = []

      # Default transform
      @offset = RVec3.new(0, 0, 0)
      @mtx_offset = RMtx4.new.setIdentity
      @default_transform = RMtx4.new.setIdentity

      # Updated via MotionData
      @rotation = RQuat.new(0, 0, 0, 1)
#      @rotation = RQuat.new.rotationAxis(RVec3.new(1,1,0).normalize!, 30.0*Math::PI/180.0)
      @position = RVec3.new(0, 0, 0)
      @mtx_position = RMtx4.new.translation(@position.x, @position.y, @position.z)
      @mtx_rotation = RMtx4.new.rotationQuaternion(@rotation)

      # For visualization
      @mtx_bone_rotation = RMtx4.new.setIdentity
      @mtx_bone_scale = RMtx4.new.setIdentity
    end

    def set_offset(x, y, z)
      @offset.setElements(x, y, z)
      @mtx_offset.translation(x, y, z)

      @mtx_bone_scale.scaling(@offset.getLength, 1.0, 1.0)

      dir = @offset.getNormalized
      dot = RVec3.dot(XAxis, dir)
      bone_rot_axis = (1.0 - dot.abs <= RMath3D::TOLERANCE) ? ZAxis : RVec3.cross(XAxis, dir).normalize!
      bone_rot_theta = Math.acos(dot)
puts "#{@name} : #{bone_rot_axis}"
      @mtx_bone_rotation.rotationAxis(bone_rot_axis, bone_rot_theta)
    end

    def set_position(x, y, z)
      @position.setElements(x, y, z)
      @mtx_position.translation(@position.x, @position.y, @position.z)
    end

    def set_rotation(q)
      @rotation.setElements(q.x, q.y, q.z, q.w)
      @mtx_rotation.rotationQuaternion(@rotation)
    end

    def local_transform
      return @mtx_position * @mtx_offset * @mtx_rotation
    end

  end # class Joint

  class MotionData
    attr_reader :frame_count, :joint_count

    def initialize(frame_count, joint_count)
      @frame_count = frame_count
      @joint_count = joint_count

      @position_data = Array.new(frame_count) { RVec3.new(0.0, 0.0, 0.0) }
      @rotation_data = Array.new(frame_count * joint_count) { RQuat.new.setIdentity }
    end

    def set_position(frame, vec_pos)
      @position_data[frame].setElements(vec_pos.x, vec_pos.y, vec_pos.z)
    end

    def get_position(frame)
      return @position_data[frame]
    end

    def set_rotation(frame, joint_index, quat)
      @rotation_data[@joint_count * frame + joint_index].setElements(quat.x, quat.y, quat.z, quat.w)
    end

    def get_rotation(frame, joint_index)
      @rotation_data[@joint_count * frame + joint_index]
    end

  end # class MotionData

end

module BVHFormat

  module Order
    ROT_X = 0
    ROT_Y = 1
    ROT_Z = 2
    POS_X = 3
    POS_Y = 4
    POS_Z = 5
    COUNT   = 6
    UNKNOWN = 7
  end

  @@order_id_map = {
    "Xrotation" => Order::ROT_X,
    "Yrotation" => Order::ROT_Y,
    "Zrotation" => Order::ROT_Z,
    "Xposition" => Order::POS_X,
    "Yposition" => Order::POS_Y,
    "Zposition" => Order::POS_Z,
  }

  def self.order_id(name)
    return @@order_id_map[name]
  end

  class Parser

    attr_reader :root_joint, :motion_data

    def initialize(bvh_file)
      @bvh = bvh_file
      @orders = []

      @root_joint = nil
      @motion_data = nil
    end

    def parse_hierarchy_children(parent_node, name, orders)
      line = @bvh.readline.strip
      return nil if line != "{"

      node = Motion::Joint.new(parent_node, name)

      until @bvh.eof?
        line = @bvh.readline.strip
        tokens = line.scan(/[^\s]+/)
        section = tokens.shift
        case section
        when "OFFSET"
          node.set_offset(tokens[0].to_f, tokens[1].to_f, tokens[2].to_f)

        when "CHANNELS"
          order_id = []
          orders_count = tokens.shift.to_i
          orders_count.times do |i|
            order_id << BVHFormat.order_id(tokens[i])
          end
          orders << order_id

        when "JOINT"
          parse_hierarchy_children(node, tokens[0], orders)

        when "End"
          parse_hierarchy_end(node, tokens[0])
          orders << nil

        when "}"
          parent_node.children << node if parent_node != nil

          return node

        else; break
        end # End : case section
      end # End : until @bvh.eof?

      return nil
    end

    def parse_hierarchy_end(parent_node, name)
      line = @bvh.readline.strip
      return nil if line != "{"

      line = @bvh.readline.strip
      tokens = line.scan(/[^\s]+/)
      return nil if tokens.shift != "OFFSET"

      ofs_x, ofs_y, ofs_z = tokens[0].to_f, tokens[1].to_f, tokens[2].to_f

      line = @bvh.readline.strip
      return nil if line != "}"

      node = Motion::Joint.new(parent_node, name)
      node.set_offset(ofs_x, ofs_y, ofs_z)

      parent_node.children << node
    end

    def parse_hierarchy
      line = @bvh.readline.strip
      return false if line != "HIERARCHY"

      line = @bvh.readline
      tokens = line.scan(/\w+/)
      return false if tokens[0] != "ROOT"

      root_name = tokens[1]

      @root_joint = parse_hierarchy_children(nil, root_name, @orders)

      return @root_joint != nil
    end

    def parse_motion
      line = @bvh.readline.strip
      return false if line != "MOTION"

      line = @bvh.readline.strip
      tokens = line.scan(/[^\s]+/)
      return false if tokens[0] != "Frames:"

      frame_count = tokens[1].to_i

      line = @bvh.readline.strip
      tokens = line.scan(/[^\s]+/)
      return false if tokens[0] != "Frame" || tokens[1] != "Time:"

      frame_spf = tokens[2].to_f

      joint_count = @orders.length

      @motion_data = Motion::MotionData.new(frame_count, joint_count)

      #
      # frame data
      #
      mot_pos = RVec3.new
      mot_quat = RQuat.new
      mtx_accum = RMtx4.new
      mtx_rot = RMtx4.new

      frame_count.times do |f|
        line = @bvh.readline.strip
        tokens = line.scan(/[^\s]+/)
        token_index = 0

        @orders.each_with_index do |order_array, joint_index|
          mot_pos.setElements(0.0, 0.0, 0.0)
          mot_quat.setIdentity
          mtx_accum.setIdentity
          mtx_rot.setIdentity
          if order_array
            order_array.each do |order|
              val = ("%f" % tokens[token_index]).to_f
              case order
              when BVHFormat::Order::ROT_X; mtx_rot.rotationX(val * Math::PI/180.0)
              when BVHFormat::Order::ROT_Y; mtx_rot.rotationY(val * Math::PI/180.0)
              when BVHFormat::Order::ROT_Z; mtx_rot.rotationZ(val * Math::PI/180.0)
              when BVHFormat::Order::POS_X; mot_pos.x = val
              when BVHFormat::Order::POS_Y; mot_pos.y = val
              when BVHFormat::Order::POS_Z; mot_pos.z = val
              end
              mtx_accum = mtx_accum * mtx_rot
              token_index += 1
            end
          end

          mot_quat.rotationMatrix(mtx_accum)
          @motion_data.set_position(f, mot_pos) if joint_index == 0
          @motion_data.set_rotation(f, joint_index, mot_quat)
        end

      end
      return true
    end
  end

  def self.parse(bvh_file)
    parser = Parser.new(bvh_file)
    succeeded = parser.parse_hierarchy()
    return nil if not succeeded
    succeeded = parser.parse_motion()
    return nil if not succeeded

    return parser.root_joint, parser.motion_data
  end

end

module AcclaimFormat
  class ASFParser

    attr_reader :root_joint, :orders, :basis

    module Section
      VERSION       = 0
      NAME          = 1
      UNITS         = 2
      DOCUMENTATION = 3
      ROOT          = 4
      BONEDATA      = 5
      HIERARCHY     = 6
      COUNT         = 7
      UNKNOWN       = 8
    end

    module Order
      ROT_X = 0
      ROT_Y = 1
      ROT_Z = 2
      POS_X = 3
      POS_Y = 4
      POS_Z = 5
      COUNT   = 6
      UNKNOWN = 7
    end

    @@order_id_map = {
      "TX" => Order::POS_X,
      "TY" => Order::POS_Y,
      "TZ" => Order::POS_Z,
      "RX" => Order::ROT_X,
      "RY" => Order::ROT_Y,
      "RZ" => Order::ROT_Z,
    }

    @@dof_id_map = {
      "rx" => Order::ROT_X,
      "ry" => Order::ROT_Y,
      "rz" => Order::ROT_Z,
    }

    def self.order_id(name)
      return @@order_id_map[name]
    end

    def self.dof_id(name)
      return @@dof_id_map[name]
    end

    def initialize(asf_file)
      @asf = asf_file
      @current_line = nil
      @current_tokens = nil

      # header
      @current_section = Section::UNKNOWN
      @angle_type = 'deg' # or 'rad'

      @orders = Hash.new
      @basis   = Hash.new
      @joints = Hash.new

      @basis['root'] = RMtx4.new.setIdentity
      @root_joint   = Motion::Joint.new(nil, 'root')
      @length_coeff = 1.0
    end

    def readline_from_asf()
      line = ""
      begin
        line = @asf.readline.strip
      end while line =~ /^#/
      return line
    end

    def get_section(token)
      case token
      when ':version';       return Section::VERSION
      when ':name';          return Section::NAME
      when ':units';         return Section::UNITS
      when ':documentation'; return Section::DOCUMENTATION
      when ':root';          return Section::ROOT
      when ':bonedata';      return Section::BONEDATA
      when ':hierarchy';     return Section::HIERARCHY
      else                   return Section::UNKNOWN
      end
    end

    def set_section(token)
      section_here = get_section(token)
      section_changed = (section_here != Section::UNKNOWN) && (@current_section != section_here)
      @current_section = section_here if section_changed
    end

    def parse_units()
      while @current_section == Section::UNITS && @asf.eof? == false
        case @current_tokens[0]
      # when 'mass'; puts "mass: #{tokens[1]}"
        when 'angle';  @angle_type   = @current_tokens[1] # 'deg' or 'rad'
        when 'length'; @length_coeff = @current_tokens[1].to_f
        end
        update()
      end
    end

    def parse_root()
      while @current_section == Section::ROOT && @asf.eof? == false
        case @current_tokens[0]
      # when 'axis';  puts "axis: #{tokens[1]}"
      # when 'orientation'; puts "orientation: #{tokens[1...tokens.length]}"
        when 'position'; @root_joint.set_position(@current_tokens[1].to_f, @current_tokens[2].to_f, @current_tokens[3].to_f)
        when 'order'
          order_id = []
          @current_tokens[1...@current_tokens.length].each do |token|
            order_id << ASFParser.order_id(token)
          end
          @orders['root'] = order_id
        end

        update()
      end
    end

    def parse_bonedata()
      joint_name = nil
      joint_length = 0.0
      joint_dir = RVec3.new(0.0, 0.0, 0.0)
      order_id = []
      limits_count = 0 # [TODO] Implement joint limit

      # [NOTE] "%f" % "string" -> "string" : converts scientific notation to decimal notation.
      while @current_section == Section::BONEDATA && @asf.eof? == false
        case @current_tokens[0]
        when 'id';      # puts "id: #{@current_tokens[1...@current_tokens.length]}"
        when 'name';      joint_name = @current_tokens[1]
        when 'direction'; joint_dir.setElements(("%f" % @current_tokens[1]).to_f, ("%f" % @current_tokens[2]).to_f, ("%f" % @current_tokens[3]).to_f)
        when 'length';    joint_length = @current_tokens[1].to_f

        when 'axis';
          rot_angles = [ ("%f" % @current_tokens[1]).to_f, ("%f" % @current_tokens[2]).to_f, ("%f" % @current_tokens[3]).to_f ]
          rot_angles.map! { |deg| deg * Math::PI / 180.0 } if @angle_type == 'deg'
          mtx_basis = RMtx4.new.setIdentity
          mtx_rot = RMtx4.new.setIdentity
          order = @current_tokens.last.scan(/./) # ex.) @current_tokens.last == 'XYZ' -> order == ['X', 'Y', 'Z']
          order.each do |sym|
            case sym
            when 'X'; mtx_rot.rotationX(rot_angles[0])
            when 'Y'; mtx_rot.rotationY(rot_angles[1])
            when 'Z'; mtx_rot.rotationZ(rot_angles[2])
            end
            mtx_basis = mtx_rot * mtx_basis
          end
          @basis[joint_name] = mtx_basis

        when 'dof'
          order_id = []
          @current_tokens[1...@current_tokens.length].each do |token|
            order_id << ASFParser.dof_id(token)
          end
          limits_count = @current_tokens[1...@current_tokens.length].length # [TODO] Implement joint limit

        when 'limits'
          # [TODO] Implement joint limit
          # puts "limits[0]: #{@current_tokens[1...@current_tokens.length]}"
          # (limits_count-1).times do |l|
          #   line = readline_from_asf()
          #   @current_tokens = line.scan(/[^\s]+/)
          #   puts "limits[#{l+1}]: #{@current_tokens}"
          # end
          limits_count = 0

        when 'end'
          joint_dir = joint_length * joint_dir
          joint_offset = joint_dir.transformCoord(@basis[joint_name].getTransposed)
          joint = Motion::Joint.new(nil, joint_name) # [NOTE] parent joint will be set up later (in parse_hierarchy)
          joint.set_offset(joint_offset.x, joint_offset.y, joint_offset.z)
          @joints[joint_name] = joint
          @orders[joint_name] = order_id
          order_id = []
        end

        update()
      end
    end # parse_bonedata()

    def parse_hierarchy()
      while @current_section == Section::HIERARCHY && @asf.eof? == false
        update() if @current_tokens[0] == 'begin'
        break if @current_tokens[0] == 'end'

        # print "(PARENT) #{@current_tokens[0]}, (CHILDREN) #{@current_tokens[1...@current_tokens.length]}\n"
        parent_joint = @current_tokens[0] == 'root' ? @root_joint : @joints[@current_tokens[0]]
        @current_tokens[1...@current_tokens.length].each do |token|
          @joints[token].parent = parent_joint # [NOTE] parent joint setup
          parent_joint.children << @joints[token]
        end

        update()
      end
    end

    def update()
      @current_line = readline_from_asf()
      @current_tokens = @current_line.scan(/[^\s]+/)
      set_section(@current_tokens[0])
    end

    def fixup_joints(parent_joint, offset)
      if parent_joint.children.length > 0
        parent_joint.children.each do |child|
          fixup_joints(child, parent_joint.offset)
        end
      else
        name = "Site#{"%03d" % @site_id}"
        site_joint = Motion::Joint.new(parent_joint, name)
        site_joint.set_offset(parent_joint.offset.x, parent_joint.offset.y, parent_joint.offset.z)
        parent_joint.children << site_joint
        @joints[name] = site_joint
        @basis[name] = RMtx4.new.setIdentity
        @site_id += 1
      end
      offset *= 3.0
      parent_joint.set_offset(offset.x, offset.y, offset.z) #if parent_joint != @root_joint
    end

    def parse()
      update()
      until @asf.eof?
        case @current_section
        when Section::VERSION;       update()
        when Section::NAME;          update()
        when Section::DOCUMENTATION; update()

        when Section::UNITS;     parse_units()
        when Section::ROOT;      parse_root()
        when Section::BONEDATA;  parse_bonedata()
        when Section::HIERARCHY; parse_hierarchy()
        else # puts "UNKNOWN SECTION"
        end
      end

      @site_id = 0
      fixup_joints(@root_joint, RVec3.new(0.0, 0.0, 0.0))

      return true
    end

  end # class ASFParser

  class AMCParser
    attr_reader :motion_data

    def initialize(amc_file, skeleton, asf_orders, asf_basis)
      @amc = amc_file
      @current_line = nil
      @current_tokens = nil

      @motion_data = nil

      @skeleton = skeleton
      @orders = asf_orders
      @basis = asf_basis
    end

    def parse()
      # 1st pass : count total frames
      frame_count = 0
      until @amc.eof?
        update()
        frame_count = @current_tokens[0].to_i if @current_tokens.length == 1
      end
      @amc.rewind

      # 2nd pass : fill Motion::MotionData
      current_frame = 0
      mot_pos = RVec3.new
      mot_quat = RQuat.new
      mtx_accum = RMtx4.new.setIdentity
      mtx_rot = RMtx4.new.setIdentity
      @motion_data = Motion::MotionData.new(frame_count, @skeleton.get_joint_count)
      until @amc.eof?
        update()
        case @current_tokens.length
        when 1 # Frame ID (1, 2, ..., frame_count)
          current_frame = @current_tokens[0].to_i
          next
        else # Motion data for each joints (name position/angle, name position/angle, ...)
          mot_pos.setElements(0.0, 0.0, 0.0)
          mot_quat.setIdentity
          mtx_accum.setIdentity
          mtx_rot.setIdentity
          token_index = 1
          joint_index = @skeleton.find_joint_index(@current_tokens[0])

          order = @orders[@current_tokens[0]]
          order.each do |id|
            val = ("%f" % @current_tokens[token_index]).to_f
            case id
            when ASFParser::Order::ROT_X; mtx_rot.rotationX(val * Math::PI/180.0)
            when ASFParser::Order::ROT_Y; mtx_rot.rotationY(val * Math::PI/180.0)
            when ASFParser::Order::ROT_Z; mtx_rot.rotationZ(val * Math::PI/180.0)
            when ASFParser::Order::POS_X; mot_pos.x = val
            when ASFParser::Order::POS_Y; mot_pos.y = val
            when ASFParser::Order::POS_Z; mot_pos.z = val
            end
            mtx_accum = mtx_rot * mtx_accum
            token_index += 1
          end
          joint = @skeleton.get_joint(joint_index)
          mtx_joint = @basis[joint.name]
          if joint.parent != nil
            mtx_parent_joint = @basis[joint.parent.name].getTransposed
            mtx_joint = mtx_joint * mtx_parent_joint
          end
          mtx_accum = mtx_joint * mtx_accum
          mot_quat.rotationMatrix(mtx_accum)
          @motion_data.set_position(current_frame-1, mot_pos) if joint_index == 0
          @motion_data.set_rotation(current_frame-1, joint_index, mot_quat)
        end
      end

      return true
    end # def parse()

    def readline_from_amc()
      line = ""
      begin
        line = @amc.readline.strip
      end while line =~ /^[#:]/
      return line
    end

    def update()
      @current_line = readline_from_amc()
      @current_tokens = @current_line.scan(/[^\s]+/)
    end
  end # class AMCParser

  def self.parse_asf(asf_file)
    parser = ASFParser.new(asf_file)
    succeeded = parser.parse()
    return nil if not succeeded

    return parser
  end

  def self.parse_amc(amc_file, skeleton, asf_orders, asf_basis)
    parser = AMCParser.new(amc_file, skeleton, asf_orders, asf_basis)
    succeeded = parser.parse()
    return nil if not succeeded

    return parser
  end

end
