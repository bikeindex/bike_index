class BikeV2Serializer < ActiveModel::Serializer
  attributes :id,
    :title,
    :serial,
    :manufacturer_name,
    :frame_model,
    :year,
    :frame_colors,    
    :thumb,
    :large_img,
    :is_stock_img,
    :stolen,
    :stolen_location,
    :date_stolen

  def manufacturer_name
    object.mnfg_name
  end
  
  def title
    object.title_string
  end

  def date_stolen
    object.current_stolen_record && object.current_stolen_record.date_stolen.to_i
  end

  def thumb
    if object.public_images.present?
      object.public_images.first.image_url(:small)
    elsif object.stock_photo_url.present?
      small = object.stock_photo_url.split('/')
      ext = "/small_" + small.pop
      small.join('/') + ext
    end
  end

  def large_img
    if object.public_images.present?
      object.public_images.first.image_url(:large)
    elsif object.stock_photo_url.present?
      object.stock_photo_url
    end
  end

  def is_stock_img
    object.public_images.present? ? false : object.stock_photo_url.present?
  end

  def stolen_location
    object.current_stolen_record && object.current_stolen_record.address_short

  end

end
