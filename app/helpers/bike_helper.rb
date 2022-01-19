# There is also BikeDisplayer for things that aren't only used in view files
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

  def bike_title_html(bike, include_status: false)
    content_tag(:span) do
      if include_status && bike_status_span(bike).present?
        concat(bike_status_span(bike))
        concat(" ")
      end
      year_and_mnfg = [bike.year, bike.mnfg_name].compact.join(" ")
      concat(content_tag(:strong, year_and_mnfg))
      concat(" #{bike.frame_model_truncated}") if bike.frame_model.present?
      if bike.type != "bike"
        concat(content_tag(:em, " #{bike.type&.titleize}"))
      end
    end
  end
end
