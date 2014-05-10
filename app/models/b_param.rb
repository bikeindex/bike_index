# b_param stands for Bike param
class BParam < ActiveRecord::Base
  attr_accessible :params,
    :creator_id,
    :bike_title,
    :created_bike_id,
    :bike_token_id,
    :bike_errors,
    :image

  mount_uploader :image, ImageUploader
  process_in_background :image

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
    set_wheel_size_key unless bike[:rear_wheel_size_id].present?
    set_manufacturer_key unless bike[:manufacturer_id].present?
    set_color_key unless bike[:primary_frame_color_id].present?
    set_cycle_type_key if bike[:cycle_type_slug].present?
    set_handlebar_type_key if bike[:handlebar_type_slug].present?
    set_frame_material_key if bike[:frame_material_slug].present?
  end

  def set_cycle_type_key
    ct = CycleType.find(:first, :conditions => [ "slug = ?", bike[:cycle_type_slug].downcase.strip ])
    bike[:cycle_type_id] = ct.id if ct.present?
    bike.delete(:cycle_type_slug)
  end

  def set_frame_material_key
    fm = FrameMaterial.find(:first, :conditions => [ "slug = ?", bike[:frame_material_slug].downcase.strip ])
    bike[:frame_material_id] = fm.id if fm.present?
    bike.delete(:frame_material_slug)
  end

  def set_handlebar_type_key
    ht = HandlebarType.find(:first, :conditions => [ "slug = ?", bike[:handlebar_type_slug].downcase.strip ])
    bike[:handlebar_type_id] = ht.id if ht.present?
    bike.delete(:handlebar_type_slug)
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
    return false unless m_name.present?
    manufacturer = Manufacturer.fuzzy_name_find(m_name)
    unless manufacturer.present?
      manufacturer = Manufacturer.find_by_name("Other")
      bike[:manufacturer_other] = m_name.titleize if m_name.present?
    end
    bike[:manufacturer_id] = manufacturer.id if manufacturer.present?
    bike.delete(:manufacturer)
  end

  def set_color_key
    paint = params[:bike][:color]
    color = Color.fuzzy_name_find(paint.strip) if paint.present?
    if color.present?
      bike[:primary_frame_color_id] = color.id
    else
      set_paint_key(paint)
    end
    self.bike.delete(:color)
  end

  def set_paint_key(paint_entry)
    return nil unless paint_entry.present?
    paint = Paint.fuzzy_name_find(paint_entry)
    if paint.present?
      bike[:paint_id] = paint.id
      bike[:primary_frame_color_id] = paint.color.id if paint.color_id.present?
    else
      paint = Paint.new(name: paint_entry)
      paint.manufacturer_id = bike[:manufacturer_id] if bike[:registered_new]
      paint.save
      params[:bike][:paint_id] = paint.id
    end
    bike[:primary_frame_color_id] = Color.find_by_name("Black").id unless bike[:primary_frame_color_id].present?
  end

end
