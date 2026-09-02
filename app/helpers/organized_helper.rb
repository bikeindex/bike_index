# frozen_string_literal: true

# TODO: add translations
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
        concat(content_tag(:small, render(Pages::Org::OriginDisplay::Component.new(creation_description: bike.creation_description)), class: "less-strong"))
      end
    end
  end

  # Used in two places, so... putting it here. Probably is a better place somewhere else
  def parking_notification_repeat_kinds
    ParkingNotification.kinds_humanized.map { |k, v| [v, k] } + [["Mark retrieved/resolved", "mark_retrieved"]]
  end

  def export_progress_class(export)
    return "text-danger" if export.calculated_progress == "errored"

    (export.calculated_progress == "finished") ? "text-success" : "text-warning"
  end

  # Whether the export's sticker assignment is still in effect
  def export_stickers_badge_attributes(export)
    if export.bike_codes_undone?
      {text: t("organized.exports.index.stickers_unassigned"),
       title: t("organized.exports.index.stickers_undone_title"), color: :warning}
    elsif export.bike_codes_removed?
      {text: t("organized.exports.index.stickers_removed"),
       title: t("organized.exports.index.stickers_removed_title"), color: :orange}
    else
      {text: t("organized.exports.index.stickers"),
       title: t("organized.exports.index.stickers_title"), color: :cyan}
    end
  end

  def organized_container
    fluid = %w[parking_notifications impound_records impound_claims graduated_notifications lines model_audits registrations]
    return "container-fluid" if fluid.include?(controller_name)

    if controller_name == "bulk_imports" && action_name == "show"
      return "container-fluid"
    end
    "container"
  end

  def organized_include_javascript_pack?
    return true if organized_container == "container-fluid"

    [
      %w[bikes recoveries],
      %w[bikes incompletes],
      %w[exports show],
      %w[exports new],
      %w[users new],
      %w[dashboard index],
      %w[impounded_bikes index]
    ].include?([controller_name, action_name])
  end

  def status_display_class(status)
    return "" if status.blank?

    case status.downcase
    when "current", "paging", "being_helped"
      "text-success"
    when "stolen", /uncertified/
      "text-warning"
    when "resolved_otherwise", "on_deck", /approved/, /retrieved/, "bike graduated", /certified_by/
      "text-info"
    when /removed/, "impounded", "trashed", "failed_to_find", /denied/, "delivery failure"
      UI::Alerts::Base::Component::TEXT_CLASSES[:error]
    else
      "less-strong"
    end
  end

  # This is (roughly) duplicated in parking_notifications.js
  def status_display(status)
    status_str = status.tr("_", " ")
    status_str.gsub!(/ otherwise/i, "") if status_str.match?(/resolved otherwise/i)
    content_tag(:span, status_str, class: status_display_class(status))
  end

  # Might make this more fancy sometime, but... for now, good enough
  def email_time_display(datetime)
    return "" unless datetime.present?

    l datetime, format: :dotted
  end
end
