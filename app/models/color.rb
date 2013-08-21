class Color < ActiveRecord::Base
  attr_accessible :name, :priority
  validates_presence_of :name, :priority
  validates_uniqueness_of :name
  has_many :bikes

  default_scope order(:name)
  scope :commonness, order("priority ASC")
end
