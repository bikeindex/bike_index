class PublicImageSerializer < ActiveModel::Serializer
  self.root = 'images'
  attributes :name, :image
end
