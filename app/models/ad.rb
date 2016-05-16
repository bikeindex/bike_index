=begin
*****************************************************************
* File: app/models/ad.rb 
* Name: Class Ad 
* Some informon some atributs and some associations
*****************************************************************
=end

class Ad < ActiveRecord::Base

  #some params to use in title
  attr_accessible :title,
    :body,
    :image,
    :image_cache,
    :organization_id,
    :target_url,
    :live

  #associaton with organization
  belongs_to :organization
  
  #validations
  validates_presence_of :title
  validates_uniqueness_of :title

  mount_uploader :image, PartnerUploader

  scope :live, -> { where(live: true) }

end
