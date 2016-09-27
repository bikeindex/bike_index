class FrameMaterial < ActiveRecord::Base
  include FriendlySlugFindable
  validates_presence_of :name, :slug
  validates_uniqueness_of :name, :slug
  has_many :bikes
  default_scope { order(:name) }

  def self.steel
    where(name: 'Steel', slug: 'steel').first_or_create
  end
end
