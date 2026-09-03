# There is also BikeServices::Displayer for things that aren't only used in view files
module BikeHelper
  def bike_status_span(bike, override_to_for_sale: false)
    status_humanized = override_to_for_sale ? "for sale" : bike.status_humanized
    return "" if status_humanized == "with owner" # for sale is status_with_owner

    content_tag(:strong,
      Bike.status_humanized_translated(status_humanized),
      class: "#{status_humanized.tr(" ", "-")}-color uppercase bike-status-html")
  end

  def bike_thumb_image(bike)
    thumb_image_url = BikeServices::Displayer.thumb_image_url(bike)
    if thumb_image_url.present?
      image_tag(thumb_image_url, alt: bike.title_string, skip_pipeline: true)
    else
      image_tag(bike_placeholder_image_path, alt: bike.title_string, title: "No image", class: "no-image tw:bg-gray-100 tw:dark:bg-gray-800")
    end
  end

  def bike_title_html(bike, include_status: false)
    content_tag(:span) do
      concat(deleted_span) if bike.deleted?
      if include_status && bike_status_span(bike).present?
        concat(bike_status_span(bike))
        concat(" ")
      end
      year_and_mnfg = [bike.year, bike.mnfg_name].compact.join(" ")
      concat(content_tag(:strong, year_and_mnfg))
      concat(" #{bike.frame_model_truncated}") if bike.frame_model.present?
      if bike.type != "bike"
        concat(content_tag(:em, " #{bike.type_titleize}", class: "less-strong"))
      end
    end
  end

  def bike_placeholder_image_path
    image_path("revised/bike_photo_placeholder.svg")
  end

  private

  def deleted_span
    content_tag(:strong, "#{I18n.t("deleted", scope: %i[helpers bike_helper])} ",
      class: "tw:text-red-500")
  end
end
