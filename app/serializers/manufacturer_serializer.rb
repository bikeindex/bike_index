class ManufacturerSerializer < ActiveModel::Serializer
  attributes :name,
    :website,
    :api_url

  def api_url
    api_v1_manufacturer_url(object)
  end

end