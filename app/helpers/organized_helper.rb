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
    fluid = %w[parking_notifications impound_records impound_claims graduated_notifications lines model_audits]
    return "container-fluid" if fluid.include?(controller_name)
    controller_name == "bikes" && action_name == "index" ? "container-fluid" : "container"
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
    when "current", "paging", "being_helped", /\Acertified/
      "text-success"
    when "resolved_otherwise", "on_deck", /approved/, /retrieved/, "bike graduated"
      "text-info"
    when /removed/, "impounded", "trashed", "failed_to_find", /denied/, /uncertified/
      "text-danger"
    when "stolen"
      "text-warning"
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

  def retrieval_link_url(obj)
    if obj.is_a?(ParkingNotification)
      return nil if obj.retrieval_link_token.blank?
      bike_url(obj.bike.to_param, parking_notification_retrieved: obj.retrieval_link_token)
    elsif obj.is_a?(GraduatedNotification)
      return nil if obj.marked_remaining_link_token.blank?
      bike_url(obj.bike.to_param, graduated_notification_remaining: obj.marked_remaining_link_token)
    end
  end

  def include_field_reg_extra_registration_number?(organization = nil, user = nil)
    organization.present? &&
      organization.additional_registration_fields.include?("reg_extra_registration_number")
  end

  def include_field_reg_organization_affiliation?(organization = nil, user = nil)
    return false unless organization.present? &&
      organization.additional_registration_fields.include?("reg_organization_affiliation")
    return true if user.blank?
    user.user_registration_organizations.with_organization_affiliation(organization.id).none?
  end

  def include_field_reg_address?(organization = nil, user = nil)
    return false unless organization.present? &&
      organization.additional_registration_fields.include?("reg_address")
    !user&.address_set_manually?
  end

  def include_field_reg_phone?(organization = nil, user = nil)
    return false unless organization.present? &&
      organization.additional_registration_fields.include?("reg_phone")
    !user&.phone&.present?
  end

  def include_field_reg_bike_sticker?(organization = nil, user = nil, require_user_editable = false)
    reg_field = organization.present? &&
      organization.additional_registration_fields.include?("reg_bike_sticker")
    return reg_field unless reg_field && require_user_editable
    organization.enabled?("bike_stickers_user_editable")
  end

  def include_field_reg_student_id?(organization = nil, user = nil)
    return false unless organization.present? &&
      organization.additional_registration_fields.include?("reg_student_id")
    return true if user.blank?
    user.user_registration_organizations.with_student_id(organization.id).none?
  end

  def registration_field_label(organization = nil, field_slug = nil, strip_tags: false)
    txt = organization&.registration_field_labels&.dig(field_slug.to_s)
    return nil unless txt.present?
    strip_tags ? strip_tags(txt) : txt.html_safe
  end

  def registration_field_address_placeholder(organization = nil)
    I18n.t(organization&.school? ? :address_school : :address, scope: %i[helpers organization_helper])
  end

  def registration_address_required_below_helper(organization = nil)
    return nil unless organization&.additional_registration_fields&.include?("reg_address")
    content_tag(:span,
      I18n.t(:your_full_address_is_required, scope: %i[helpers organization_helper], org_name: organization.short_name),
      class: "below-input-help text-warning")
  end
end
