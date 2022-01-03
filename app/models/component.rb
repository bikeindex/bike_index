class Component < ApplicationRecord
  include ActiveModel::Dirty

  attr_accessor :front_or_rear, :mnfg_name, :setting_is_stock

  def model_name=(val)
    self.component_model = val
  end

  belongs_to :manufacturer
  belongs_to :ctype
  belongs_to :bike

  before_save :set_front_or_rear

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

  def manufacturer_name
    if manufacturer && manufacturer.name == "Other" && manufacturer_other.present?
      manufacturer_other
    else
      manufacturer&.name
    end
  end

  before_save :set_is_stock

  def set_is_stock
    return true if setting_is_stock
    if id.present? && is_stock && description_changed? || component_model_changed?
      self.is_stock = false
    end
    true
  end

  before_validation :set_manufacturer

  def set_manufacturer
    return true unless mnfg_name.present?
    self.manufacturer_id = Manufacturer.friendly_id_find(mnfg_name)
  end
end
