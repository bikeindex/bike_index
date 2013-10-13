class Country < ActiveRecord::Base
  attr_accessible :name, :iso
  validates_presence_of :name
  validates_uniqueness_of :name
  validates_uniqueness_of :iso
  has_many :stolen_records

end
