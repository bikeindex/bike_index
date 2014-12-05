class ManufacturerV2ShowSerializer < ActiveModel::Serializer
  attributes :name,
    :company_url,
    :id,
    :frame_maker,
    :image,
    :description,
    :slug

  self.root = "manufacturer"

  def company_url
    return "" unless object.website
    object.website
  end

  def image
    return "" unless object.logo_url.present? && object.logo_url.match('/blank.png').blank?
    object.logo_url
  end
end