class CycleType < ActiveRecord::Base # Defines things like unicycles and recumbent
  include FriendlySlugFindable

  has_many :bikes

  def self.bike
    where(name: 'Bike', slug: 'bike').first_or_create
  end
end
