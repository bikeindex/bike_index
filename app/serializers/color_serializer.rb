class ColorSerializer < ActiveModel::Serializer
  attributes :name, :slug

  def slug
    name.downcase.split(/\W+/).first
  end
end
