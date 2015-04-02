module CarrierWave
  module MiniMagick
    # check for images that are too large
    def validate_dimensions
      manipulate! do |img|
        raise CarrierWave::ProcessingError, "dimensions too large" if img.dimensions.any?{|i| i > 8000 }
      end      
    end
    # Rotates the image based on the EXIF Orientation
    def fix_exif_rotation
      manipulate! do |img|
        img.auto_orient
        img = yield(img) if block_given?
        img
      end
    end 
    # Strips out all embedded information from the image
    def strip
      manipulate! do |img|
        img.strip
        img = yield(img) if block_given?
        img
      end
    end
  end
end