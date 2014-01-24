class ManufacturerSerializer < ActiveModel::Serializer
  attributes :name,
    :company_url

  def company_url
    return "" unless object.website
    object.website
  end
end