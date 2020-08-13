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
        concat(content_tag(:em, bike.frame_model_truncated))
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
        concat(content_tag(:small, origin_display(bike.creation_description), class: "less-strong"))
      end
    end
  end

  def origin_display(creation_description)
    return "" unless creation_description.present?
    extended_description = {
      "web" => "Registered with self registration process",
      "org reg" => "Registered by internal, organization member form",
      "landing page" => "Registration began with incomplete registration, via organization landing page",
      "bulk reg" => "Registered by spreadsheet import"
    }
    origin_title = "Automatically registered by bike shop point of sale (#{creation_description} POS)" if %w[Lightspeed Ascend].include?(creation_description)
    origin_title ||= extended_description[creation_description] || "Registered via #{creation_description}"
    content_tag(:span, creation_description, title: origin_title)
  end

  # Used in two places, so... putting it here. Probably is a better place somewhere else
  def parking_notification_repeat_kinds
    ParkingNotification.kinds_humanized.map { |k, v| [v, k] } + [["Mark retrieved/resolved", "mark_retrieved"]]
  end

  def export_progress_class(export)
    return "text-danger" if export.calculated_progress == "errored"
    export.calculated_progress == "finished" ? "text-success" : "text-warning"
  end

  def organized_container
    return "container-fluid" if %w[parking_notifications impound_records graduated_notifications lines].include?(controller_name)
    controller_name == "bikes" && action_name == "index" ? "container-fluid" : "container"
  end

  def organized_include_javascript_pack?
    return true if organized_container == "container-fluid"
    [
      %w[bikes recoveries],
      %w[bikes incompletes],
      %w[exports show],
      %w[users new],
      %w[dashboard index]
    ].include?([controller_name, action_name])
  end

  # This is duplicated in parking_notifications.js
  def status_display(status)
    status_str = status.tr("_", " ")
    case status.downcase
    when "current", "paging", "being_helped"
      content_tag(:span, status_str, class: "text-success")
    when /retrieved/, "resolved_otherwise", "on_deck"
      content_tag(:span, status_str.gsub("otherwise", ""), class: "text-info")
    when /removed/, "impounded", "trashed", "failed_to_find"
      content_tag(:span, status_str, class: "text-danger")
    else
      content_tag(:span, status_str, class: "less-strong")
    end
  end
end
