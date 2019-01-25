class Ad < ActiveRecord::Base

  belongs_to :organization
  validates_presence_of :title
  validates_uniqueness_of :title

  mount_uploader :image, PartnerUploader

  scope :live, -> { where(live: true) }

end
