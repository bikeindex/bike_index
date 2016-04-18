class PropulsionType < ActiveRecord::Base
  attr_accessible :name
  validates_presence_of :name
  validates_uniqueness_of :name
  has_many :bikes

  before_create :set_slug
  def set_slug
    self.slug = Slugifyer.slugify(self.name)
  end

  def self.foot_pedal
    first_or_create(name: 'Foot pedal')
  end
end
