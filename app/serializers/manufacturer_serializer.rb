class ManufacturerSerializer < ActiveModel::Serializer
  attributes :name,
    :company_url,
    :short_name,
    :id

  def company_url
    return "" unless object.website
    object.website
  end

  def short_name; simple_name end
end
