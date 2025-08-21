# == Schema Information
#
# Table name: public_images
#
#  id                 :integer          not null, primary key
#  external_image_url :text
#  image              :string(255)
#  imageable_type     :string(255)
#  is_private         :boolean          default(FALSE), not null
#  kind               :integer          default("photo_uncategorized")
#  listing_order      :integer          default(0)
#  name               :string(255)
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  imageable_id       :integer
#
# Indexes
#
#  index_public_images_on_imageable_id_and_imageable_type  (imageable_id,imageable_type)
#
class PublicImageSerializer < ApplicationSerializer
  self.root = "images"
  attributes :name,
    :full,
    :large,
    :medium,
    :thumb,
    :id

  def full
    object.image_url
  end

  def large
    object.image_url(:large)
  end

  def medium
    object.image_url(:medium)
  end

  def thumb
    object.image_url(:small)
  end
end
