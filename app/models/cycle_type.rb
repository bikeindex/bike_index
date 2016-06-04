class CycleType < ActiveRecord::Base
  # Defines things like unicycles and recumbent
  attr_accessible :name, :slug

  validates_presence_of :name, :slug
  validates_uniqueness_of :name, :slug

  has_many :bikes

  def self.bike
    CycleType.first_or_create(name: 'Bike', slug: 'bike')
  end
end
