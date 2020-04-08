# frozen_string_literal: true

module OrganizedHelper
  def organized_bike_text(bike = nil)
    return nil unless bike.present?
    content_tag(:span) do
      concat(bike.frame_colors.to_sentence)
      concat(" ")
      concat(content_tag(:strong, bike.mnfg_name))
      if bike.frame_model.present?
        concat(" ")
        concat(content_tag(:em, bike.frame_model))
      end
      if bike.creation_description.present?
        if bike.unregistered_parking_notification?
          concat(content_tag(:em, " unregistered, parking notification", class: "small"))
        else
          concat(", ")
          concat(content_tag(:small, bike.creation_description, class: "less-strong"))
        end
      end
    end
  end

  def export_progress_class(export)
    return "text-danger" if export.calculated_progress == "errored"
    export.calculated_progress == "finished" ? "text-success" : "text-warning"
  end

  def organized_container
    return "container-fluid" if %w[parking_notifications messages].include?(controller_name)
    controller_name == "bikes" && action_name == "index" ? "container-fluid" : "container"
  end

  def organized_include_javascript_pack?
    return true if organized_container == "container-fluid"
    [
      %w[bikes recoveries],
      %w[exports show],
      %w[users new],
      %w[dashboard index],
    ].include?([controller_name, action_name])
  end
end
