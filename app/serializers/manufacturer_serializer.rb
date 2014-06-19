class ManufacturerSerializer < ActiveModel::Serializer
  attributes :name,
    :company_url,
    :id

  def company_url
    return "" unless object.website
    object.website
  end
end