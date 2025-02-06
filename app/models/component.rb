# == Schema Information
#
# Table name: components
#
#  id                 :integer          not null, primary key
#  component_model    :string(255)
#  ctype_other        :string(255)
#  description        :text
#  front              :boolean
#  is_stock           :boolean          default(FALSE), not null
#  manufacturer_other :string(255)
#  mnfg_name          :string
#  rear               :boolean
#  serial_number      :string(255)
#  year               :integer
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  bike_id            :integer
#  bike_version_id    :bigint
#  ctype_id           :integer
#  manufacturer_id    :integer
#
# Indexes
#
#  index_components_on_bike_id          (bike_id)
#  index_components_on_bike_version_id  (bike_version_id)
#  index_components_on_manufacturer_id  (manufacturer_id)
#
class Component < ApplicationRecord
  include ActiveModel::Dirty

  attr_accessor :front_or_rear, :setting_is_stock

  def self.permitted_attributes
    %i[id component_model year ctype ctype_id ctype_other manufacturer manufacturer_id mnfg_name
      manufacturer_other description bike_id bike serial_number front rear front_or_rear _destroy]
  end

  def model_name=(val)
    self.component_model = val
  end

  belongs_to :manufacturer
  belongs_to :ctype
  belongs_to :bike
  belongs_to :bike_version

  before_save :set_calculated_attributes

  def version_duplicated_attrs
    {component_model: component_model,
     year: year,
     description: description,
     manufacturer_id: manufacturer_id,
     ctype_id: ctype_id,
     ctype_other: ctype_other,
     front: front,
     rear: rear,
     manufacturer_other: manufacturer_other,
     serial_number: serial_number,
     is_stock: is_stock}
  end

  def set_front_or_rear
    return true unless front_or_rear.present?
    position = front_or_rear.downcase.strip
    self.front_or_rear = ""
    if position == "both"
      f = dup
      f.front = true
      f.save
      self.rear = true
    elsif position == "front"
      self.front = true
    elsif position == "rear"
      self.rear = true
    end
  end

  def component_type
    return nil unless ctype.present?
    if ctype.name && ctype.name == "Other" && ctype_other.present?
      ctype_other
    else
      ctype.name
    end
  end

  def cgroup_id
    ctype.present? ? ctype.cgroup_id : Cgroup.additional_parts.id
  end

  def component_group
    return "Additional parts" unless ctype.present?
    ctype.cgroup.name
  end

  def set_is_stock
    return true if setting_is_stock
    if id.present? && is_stock && description_changed? || component_model_changed?
      self.is_stock = false
    end
  end

  def set_calculated_attributes
    set_front_or_rear
    set_is_stock
    self.mnfg_name = Manufacturer.calculated_mnfg_name(manufacturer, manufacturer_other)
  end
end
