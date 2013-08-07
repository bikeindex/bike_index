class FrontGearType < ActiveRecord::Base
  attr_accessible :name, :count, :internal
  validates_presence_of :name, :count
  validates_uniqueness_of :name
  has_many :bikes

end
