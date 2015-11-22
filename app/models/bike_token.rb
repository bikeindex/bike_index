class BikeToken < ActiveRecord::Base
  attr_accessible :user, :organization

  belongs_to :bike
  belongs_to :user
  belongs_to :organization
  has_many :b_params
  validates_presence_of :user, :organization

  scope :available, -> { where(bike_id: nil) }

  before_save :set_used_at
  def set_used_at
    if bike_id.present? and bike_id_changed? and used_at.nil?
      self.used_at = Time.zone.now
    end
  end

  after_save :update_bike_organization
  def update_bike_organization
    if self.bike.present?
      self.bike.creation_organization = self.organization
      self.bike.save
    end
  end

  def used?
    !self.bike_id.nil?
  end
end
