class SingleBikeSerializer < BikeSerializer
  has_many :components
  has_many :public_images

end
