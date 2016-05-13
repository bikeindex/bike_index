class SingleBikeSerializer < BikeSerializer
  self.root = 'bikes'
  attributes :images 
  has_many :components

  def images
    object.publicImages
  end

end
