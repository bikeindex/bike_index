class Component < ActiveRecord::Base
  attr_accessible :model_name,
    :year,
    :ctype,
    :ctype_id,
    :ctype_other,
    :manufacturer,
    :manufacturer_id,
    :manufacturer_other,
    :description,
    :bike_id,
    :bike,
    :serial_number,
    :front,
    :rear,
    :front_or_rear
    
  attr_accessor :front_or_rear

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
    if ctype.present?
      self.ctype.cgroup_id
    else
      Cgroup.find_by_slug('additional-parts').id
    end
  end

  def component_group
    return "Additional parts" unless ctype.present?
    self.ctype.cgroup.name
  end

  def manufacturer_name
    return nil unless self.manufacturer
    if self.manufacturer.name == "Other" && self.manufacturer_other.present?
      return self.manufacturer_other
    else
      return self.manufacturer.name 
    end
  end

end
