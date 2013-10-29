class RearGearType < ActiveRecord::Base
  attr_accessible :name, :count, :internal, :standard
  validates_presence_of :name, :count
  validates_uniqueness_of :name
  has_many :bikes

  scope :standard, where(standard: true)
  scope :internal, where(internal: true)
  scope :fixed, where(name: "Fixed")
end
