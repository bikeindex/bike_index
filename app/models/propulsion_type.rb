class PropulsionType < ActiveRecord::Base
  def self.old_attr_accessible
    %w(name).map(&:to_sym).freeze
  end
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
