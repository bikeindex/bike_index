class LockType < ActiveRecord::Base
  attr_accessible :name, :slug
  validates_presence_of :name
  validates_uniqueness_of :name
  validates_uniqueness_of :slug

  
  
  before_create :set_slug
  def set_slug
    self.slug = Slugifyer.slugify(self.name)
  end
end
