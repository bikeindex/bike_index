class ManufacturerSerializer < ActiveModel::Serializer
  attributes :id,
    :name,
    :slug,
    :url,
    :api_url,
    :website,
    :frame_maker,
    :logo_location,
    :description

  def url
    manufacturer_url(object)
  end
  def api_url
    api_v1_manufacturer_url(object)
  end

end
