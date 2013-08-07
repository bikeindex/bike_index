class Lock < ActiveRecord::Base
  attr_accessible :lock_type_id,
    :has_key,
    :has_combination,
    :combination,
    :key_serial,
    :manufacturer_id,
    :manufacturer_other,
    :user,
    :lock_model,
    :notes

  belongs_to :manufacturer
  belongs_to :lock_type
  belongs_to :user

  validates_presence_of :user, on: :create
  validates_presence_of :manufacturer
  validates_presence_of :lock_type

  def manufacturer_name
    if self.manufacturer.name == "Other" && self.manufacturer_other.present?
      self.manufacturer_other
    else
      self.manufacturer.name 
    end    
  end

end
