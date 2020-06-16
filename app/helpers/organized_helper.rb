# frozen_string_literal: true

module OrganizedHelper
  def organized_bike_text(bike = nil, skip_creation: false)
    return nil unless bike.present?
    content_tag(:span) do
      concat(bike.frame_colors.to_sentence)
      concat(" ")
      concat(content_tag(:strong, bike.mnfg_name))
      if bike.frame_model.present?
        concat(" ")
        concat(content_tag(:em, bike.frame_model))
      end
      unless bike.cycle_type == "bike"
        concat(content_tag(:small, " #{bike.type}"))
      end
      if bike.deleted?
        concat(content_tag(:em, " removed from Bike Index", class: "small text-danger"))
      elsif bike.unregistered_parking_notification? # Only care if currently unregistered parking notification
        # If it's an unregistered bike, don't display where it was created
        # ... since it only could've been created in one place
        concat(content_tag(:em, " unregistered", class: "small text-warning"))
      elsif !skip_creation && bike.creation_description.present?
        concat(", ")
        concat(content_tag(:small, bike.creation_description, class: "less-strong"))
      end
    end
  end

  # Used in two places, so... putting it here. Probably is a better place somewhere else
  def parking_notification_repeat_kinds
    ParkingNotification.kinds_humanized.map { |k, v| [v, k] } + [["Mark retrieved", "mark_retrieved"]]
  end

  def export_progress_class(export)
    return "text-danger" if export.calculated_progress == "errored"
    export.calculated_progress == "finished" ? "text-success" : "text-warning"
  end

  def organized_container
    return "container-fluid" if %w[parking_notifications impound_records graduated_notifications].include?(controller_name)
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

  def status_display(status)
    status_str = status.gsub("_", " ")
    case status.downcase
    when "current"
      content_tag(:span, status_str, class: "text-success")
    when /retrieved/
      content_tag(:span, status_str, class: "text-info")
    when /removed/, "impounded", "trashed"
      content_tag(:span, status_str, class: "text-danger")
    else
      content_tag(:span, status_str, class: "less-strong")
    end
  end
end
