class ColorShade < ActiveRecord::Base
  attr_accessible :name, :color, :color_id

  validates_presence_of :name
  validates_uniqueness_of :name
  belongs_to :color

  before_save { |color| color.name = color.name.downcase }

end
