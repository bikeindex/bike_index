class Creation < ActiveRecord::Base
  has_one :bike
  belongs_to :organization
  belongs_to :location
  belongs_to :creator, class_name: 'User'
  validates :creator_id, presence: true

  def self.origins
    %w(embed embed_extended embed_partial api_v1 api_v2).freeze
  end

  before_validation :ensure_permitted_origin
  def ensure_permitted_origin
    self.origin = nil unless self.class.origins.include?(origin)
    true
  end
end
