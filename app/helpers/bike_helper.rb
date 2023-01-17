# There is also BikeDisplayer for things that aren't only used in view files
module BikeHelper
  def render_serial_display(bike, user = nil, skip_explanation: false)
    serial_text = bike.serial_display(user)&.downcase
    return "" if serial_text.blank?
    serial_html = if ["hidden", "unknown", "made without serial"].include?(serial_text)
      content_tag(:span,
        I18n.t(serial_text.tr(" ", "_"), scope: %i[helpers bike_helper]),
        class: "less-strong")
    else
      content_tag(:code, bike.serial_display(user), class: "bike-serial")
    end
    return serial_html unless bike.serial_hidden? && !skip_explanation
    serial_html << " "
    serial_html << content_tag(:em, class: "small less-less-strong") do
      if bike.authorized?(user)
        I18n.t("hidden_for_unauthorized_users", scope: %i[helpers bike_helper])
      else
        I18n.t("hidden_because_status",
          bike_type: bike.type, status: bike.status_humanized_translated,
          scope: %i[helpers bike_helper])
      end
    end
  end

  def bike_status_span(bike)
    return "" if bike.status_with_owner?
    content_tag(:strong,
      bike.status_humanized_translated,
      class: "#{bike.status_humanized.tr(" ", "-")}-color uppercase bike-status-html")
  end

  def bike_thumb_image(bike)
    thumb_image_url = BikeDisplayer.thumb_image_url(bike)
    if thumb_image_url.present?
      image_tag(thumb_image_url, alt: bike.title_string, skip_pipeline: true)
    else
      image_tag(bike_placeholder_image_path, alt: bike.title_string, title: "No image", class: "no-image")
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

  def bike_placeholder_image_path
    image_path("revised/bike_photo_placeholder.svg")
  end
end
