class SingleBikeSerializer < BikeSerializer
  self.root = 'bikes'
  attributes :images 
  has_many :components

  def images
    object.public_images
  end

end
