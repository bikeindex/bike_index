class PropulsionType < ActiveRecord::Base
  include FriendlySlugFindable
  has_many :bikes

  def self.foot_pedal
    where(name: 'Foot pedal').first_or_create
  end
end
