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
    set_manufacturer_keys if params[:bike][:manufacturer_name].present?
    set_primary_color_key if params[:bike][:primary_frame_color_name].present?
  end

  def set_manufacturer_keys
    m_name = params[:bike][:manufacturer_name]
    manufacturer = Manufacturer.fuzzy_name_find(m_name)
    unless manufacturer.present?
      manufacturer = Manufacturer.find_by_name("Other")
      params[:bike][:manufacturer_other] = m_name.titleize
    end
    params[:bike][:manufacturer_id] = manufacturer.id
    params[:bike].delete(:manufacturer_name)
  end

  def set_primary_color_key
    c_name = params[:bike][:primary_frame_color_name]
    color = Color.find_by_name(c_name)
    color = Color.find_by_name("White") unless color.present?
    params[:bike][:primary_frame_color_id] = color.id
    params[:bike].delete(:primary_frame_color_name)
  end



end
