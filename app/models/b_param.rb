# b_param stands for Bike param
class BParam < ActiveRecord::Base
  attr_accessible :params,
    :creator_id,
    :bike_title,
    :created_bike_id,
    :bike_token_id,
    :bike_errors

  serialize :params
  serialize :bike_errors

  belongs_to :created_bike, class_name: "Bike"
  belongs_to :creator, class_name: "User"
  belongs_to :bike_token
  validates_presence_of :creator

  def bike
    params[:bike]
  end

  before_save :set_foreign_keys
  def set_foreign_keys
    return true unless params.present? && bike.present?
    set_cycle_type_key unless bike[:cycle_type_id].present?
    set_wheel_size_key unless bike[:rear_wheel_size_id].present?
    set_manufacturer_key unless bike[:manufacturer_id].present?
    set_color_key unless bike[:primary_frame_color_id].present?
  end

  def set_cycle_type_key
    bike[:cycle_type_id] = CycleType.find_by_name("Bike").id
    if bike[:cycle_type].present?
      ct = CycleType.find_by_slug(bike[:cycle_type])
      bike[:cycle_type_id] = ct.id if ct.present?
      bike.delete(:cycle_type)
    end
  end

  def set_wheel_size_key
    if bike[:rear_wheel_bsd].present?
      ct = WheelSize.find_by_iso_bsd(bike[:rear_wheel_bsd])
      bike[:rear_wheel_size_id] = ct.id if ct.present?
      bike.delete(:rear_wheel_bsd)
    end
  end

  def set_manufacturer_key
    m_name = params[:bike][:manufacturer] if bike.present?
    manufacturer = Manufacturer.fuzzy_name_find(m_name)
    unless manufacturer.present?
      manufacturer = Manufacturer.find_by_name("Other")
      bike[:manufacturer_other] = m_name.titleize if m_name.present?
    end
    bike[:manufacturer_id] = manufacturer.id if manufacturer.present?
    bike.delete(:manufacturer)
  end

  def set_color_key
    color_name = params[:bike][:color]
    color = Color.fuzzy_name_find(color_name.strip) if color_name.present?
    unless color.present?
      # if the color isn't one of the base colors,
      # Set the frame_paint_description to the color
      # look up the name in color shades, create it if it isn't there
      if color_name.present?
        bike[:frame_paint_description] = color_name 
        cshade = ColorShade.find_by_name(color_name)
        if cshade.present? 
          color = cshade.color if cshade.color_id.present?
        else
          ColorShade.create(name: color_name)
        end
      end
    end
    color = Color.find_by_name("Black") unless color.present?
    bike[:primary_frame_color_id] = color.id
    self.bike.delete(:color)
  end



end
