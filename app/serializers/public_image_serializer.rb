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
