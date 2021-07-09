# There is also BikeDisplayer for things that don't
module BikeHelper
  def bike_status_span(bike)
    return "" if bike.status_with_owner?
    content_tag(:strong,
      bike.status_humanized_translated,
      class: "#{bike.status_humanized.tr(" ", "-")}-color uppercase bike-status-html")
  end

  def bike_thumb_image(bike)
    if bike.thumb_path
      image_tag(bike.thumb_path, alt: bike.title_string, skip_pipeline: true)
    elsif bike.stock_photo_url.present?
      small = bike.stock_photo_url.split("/")
      ext = "/small_" + small.pop
      image_tag(small.join("/") + ext, alt: bike.title_string)
    else
      image_tag("revised/bike_photo_placeholder.svg", alt: bike.title_string, title: "No image", class: "no-image")
    end
  end

  def bike_title_html(bike)
    content_tag(:span) do
      concat("#{bike.year} ") if bike.year.present?
      concat(content_tag(:strong, bike.mnfg_name))
      concat(Rack::Utils.escape_html(" #{bike.frame_model_truncated}")) if bike.frame_model.present?
      concat(" #{bike.type}") if bike.type != "bike"
    end
  end
end
