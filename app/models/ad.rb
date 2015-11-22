class Ad < ActiveRecord::Base
  attr_accessible :title,
    :body,
    :image,
    :image_cache,
    :organization_id,
    :target_url,
    :live

  belongs_to :organization
  validates_presence_of :title
  validates_uniqueness_of :title

  mount_uploader :image, PartnerUploader

  scope :live, -> { where(live: true) }

end
