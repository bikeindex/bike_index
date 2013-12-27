class UsState < ActiveRecord::Base
  attr_accessible :name, :abbreviation
  validates_presence_of :name, :abbreviation
  validates_uniqueness_of :name, :abbreviation

  has_many :locations
  has_many :stolen_records

end
