class CycleType < ActiveRecord::Base # Defines things like unicycles and recumbent
  include FriendlySlugFindable
  validates_presence_of :name, :slug
  validates_uniqueness_of :name, :slug

  has_many :bikes

  def self.bike
    where(name: 'Bike', slug: 'bike').first_or_create
  end
end
