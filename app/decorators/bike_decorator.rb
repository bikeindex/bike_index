# NB: Decorators are being reconsidered for this project.
#     Maybe add more and remove view helpers? Or figure something else out
class BikeDecorator < ApplicationDecorator
  delegate_all

  def show_other_bikes?
    object.user? && object.user.show_bikes
  end

  def title
    t = ""
    t += "#{object.year} " if object.year.present?
    t += "#{object.frame_model} by " if object.frame_model.present?
    h.content_tag(:span, t) + h.content_tag(:strong, object.mnfg_name)
  end

  def status_html
    return "" if object.status_with_owner?
    h.content_tag(:strong,
                  object.status_humanized_translated,
                  class: "#{object.status_humanized.tr(" ", "-")}-color uppercase bike-status-html")
  end

  def list_link_url(target = nil)
    if target == "edit"
      "/bikes/#{object.id}/edit"
    else
      h.bike_path(object)
    end
  end

  def thumb_image
    if object.thumb_path
      h.image_tag(object.thumb_path, alt: title_string, skip_pipeline: true)
    elsif object.stock_photo_url.present?
      small = object.stock_photo_url.split("/")
      ext = "/small_" + small.pop
      h.image_tag(small.join("/") + ext, alt: title_string)
    else
      h.image_tag("revised/bike_photo_placeholder.svg", alt: title_string, title: "No image", class: "no-image")
    end
  end

  def title_html
    h.content_tag(:span) do
      h.concat("#{object.year} ") if object.year.present?
      h.concat(h.content_tag(:strong, object.mnfg_name))
      h.concat(Rack::Utils.escape_html(" #{object.frame_model_truncated}")) if object.frame_model.present?
      h.concat(" #{object.type}") if object.type != "bike"
    end
  end
end
