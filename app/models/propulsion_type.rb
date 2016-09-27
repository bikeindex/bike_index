class PropulsionType < ActiveRecord::Base
  include FriendlySlugFindable
  validates_presence_of :name
  validates_uniqueness_of :name
  has_many :bikes
  def self.foot_pedal
    where(name: 'Foot pedal').first_or_create
  end
end
