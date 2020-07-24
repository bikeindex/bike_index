class ManufacturerV2ShowSerializer < ApplicationSerializer
  attributes :name,
    :company_url,
    :id,
    :frame_maker,
    :image,
    :description,
    :short_name,
    :slug

  self.root = "manufacturer"

  def company_url
    return "" unless object.website
    object.website
  end

  def image
    return "" unless object.logo_url.present? && object.logo_url.match("/blank.png").blank?
    object.logo_url
  end

  def short_name
    object.simple_name
  end
end
