class LockType < ActiveRecord::Base
  def self.old_attr_accessible
    %w(name slug).map(&:to_sym).freeze
  end
  validates_presence_of :name
  validates_uniqueness_of :name
  validates_uniqueness_of :slug

  
  
  before_create :set_slug
  def set_slug
    self.slug = Slugifyer.slugify(self.name)
  end
end
