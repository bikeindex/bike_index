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
    :front,
    :rear,
    :bike,
    :serial_number
    

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
