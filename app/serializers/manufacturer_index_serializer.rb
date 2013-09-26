class ManufacturerIndexSerializer < ActiveModel::Serializer
  attributes :slug,
    :name,
    :api_url

  def api_url
    api_v1_manufacturer_url(object)
  end

end
