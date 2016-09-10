class CreationState < ActiveRecord::Base
  belongs_to :bike
  belongs_to :organization
  validates :bike_id, presence: true

  validates_presence_of :organization_id, unless: :origin?
  validates_presence_of :origin, unless: :organization_id?

  def self.origins
    %w(embed embed_extended embed_partial api_v1 api_v2).freeze
  end

  before_validation :ensure_allowed_origin
  def ensure_allowed_origin
    self.origin = nil unless self.class.origins.include?(origin)
    true
  end
end
