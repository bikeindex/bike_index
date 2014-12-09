class BikeV2Serializer < ActiveModel::Serializer
  self.root = 'bikes'
  attributes :id,
    :serial,
    :manufacturer_name,
    :frame_colors,
    :stolen,
    :year,
    :frame_model,
    :thumb,
    :stock_thumb,
    :title

  def manufacturer_name
    object.mnfg_name
  end
  
  def title
    object.title_string
  end
  

  def thumb
    if object.public_images.present?
      object.public_images.first.image_url(:small)
    elsif object.stock_photo_url.present?
      small = object.stock_photo_url.split('/')
      ext = "/small_" + small.pop
      small.join('/') + ext
    else
      nil
    end    
  end

  def stock_thumb
    object.stock_photo_url.present? ? true : false
  end

end
