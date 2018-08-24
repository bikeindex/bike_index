class FrameMaterial < ActiveRecord::Base
  include FriendlySlugFindable

  has_many :bikes

  default_scope { order(:name) }

  def self.steel
    where(name: 'Steel', slug: 'steel').first_or_create
  end
end
