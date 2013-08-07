class WheelSize < ActiveRecord::Base
  attr_accessible :name, :wheel_size_set, :description, :iso_bsd
  validates_presence_of :name, :wheel_size_set, :description, :iso_bsd
  validates_uniqueness_of :name, :description, :iso_bsd
  has_many :bikes

end
