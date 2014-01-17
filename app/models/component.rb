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

  def component_type
    if ctype.name && ctype.name == "Other" && ctype_other.present?
      ctype_other
    else
      ctype.name
    end
  end

  def cgroup_id
    return 0 unless ctype.present?
    ctype.cgroup.id
  end

  def component_group
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
