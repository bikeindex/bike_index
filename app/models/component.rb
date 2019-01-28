class Component < ActiveRecord::Base
  include ActiveModel::Dirty

    def self.old_attr_accessible
    %w(id cmodel_name year ctype ctype_id ctype_other manufacturer manufacturer_id mnfg_name
       manufacturer_other description bike_id bike serial_number front rear front_or_rear _destroy).map(&:to_sym).freeze
    end

  attr_accessor :front_or_rear, :mnfg_name, :setting_is_stock
  def model_name=(val)
    self.cmodel_name = val
  end

  belongs_to :manufacturer
  belongs_to :ctype
  belongs_to :bike

  before_save :set_front_or_rear
  def set_front_or_rear
    return true unless self.front_or_rear.present?
    position = self.front_or_rear.downcase.strip
    self.front_or_rear = ''
    if position == "both"
      f = self.dup
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
    ctype.present? ? self.ctype.cgroup_id : Cgroup.additional_parts.id
  end

  def component_group
    return "Additional parts" unless ctype.present?
    ctype.cgroup.name
  end

  def manufacturer_name
    if manufacturer && manufacturer.name == 'Other' && manufacturer_other.present?
      manufacturer_other
    else
      manufacturer && manufacturer.name
    end
  end

  before_save :set_is_stock
  def set_is_stock
    return true if setting_is_stock
    if id.present? && is_stock && description_changed? || cmodel_name_changed?
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
