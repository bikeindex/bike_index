class BikeV2Serializer < ActiveModel::Serializer
  attributes :id,
    :title,
    :serial,
    :manufacturer_name,
    :frame_colors,
    :stolen,
    :stolen_location,
    :year,
    :frame_model,
    :thumb,
    :stock_thumb,
    :title,
    :updated_at

  def manufacturer_name
    object.mnfg_name
  end
  
  def title
    object.title_string
  end

  def updated_at
    object.updated_at.to_i
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

  def stolen_location
    return nil unless object.current_stolen_record.present?
    sr = object.current_stolen_record
    a = [sr.city]
    a << sr.state.abbreviation if sr.state.present?
    a << sr.zipcode if sr.zipcode.present?
    a << sr.country.iso if sr.country.present? && sr.country.iso != 'US'
    a.compact.join(', ')
  end

end
