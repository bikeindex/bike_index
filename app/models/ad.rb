class Ad < ActiveRecord::Base
  def self.old_attr_accessible
    %w(title body image image_cache organization_id target_url live).map(&:to_sym).freeze
  end

  belongs_to :organization
  validates_presence_of :title
  validates_uniqueness_of :title

  mount_uploader :image, PartnerUploader

  scope :live, -> { where(live: true) }

end
