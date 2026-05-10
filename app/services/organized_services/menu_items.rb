# frozen_string_literal: true

# Builds the data for the organization menu (sidebar + dropdown).
#
# Each returned item is a Hash with one of these shapes:
#   {type: :divider}
#   {type: :disabled, label:, secondary:}
#   {type: :link, label:, path:, secondary:, match_controller:, active:}
#   {type: :super_admin_link, label:, path:}
#
# `active:` is true | false | :auto. Items marked :auto rely on the
# `active_link` view helper to compare paths against the current request.
module OrganizedServices
  module MenuItems
    extend Functionable

    def for(organization:, current_user:, controller_name: nil, action_name: nil,
      unregistered_parking_notification: nil, is_dropdown: false)
      return [] if organization.nil?

      if organization.ambassador?
        ambassador_items(organization)
      else
        standard_items(organization:, current_user:, controller_name:, action_name:,
          unregistered_parking_notification:, is_dropdown:)
      end + super_admin_items(organization, current_user)
    end

    def ambassador_items(organization)
      [
        link(translation(:org_dashboard, org_name: organization.short_name),
          routes.organization_ambassador_dashboard_path(organization_id: organization.to_param)),
        link(translation(:resources),
          routes.resources_organization_ambassador_dashboard_path(organization_id: organization.to_param)),
        link(translation(:getting_started),
          routes.getting_started_organization_ambassador_dashboard_path(organization_id: organization.to_param)),
        link(translation(:multi_search),
          routes.multi_search_organization_registrations_path(organization_id: organization.to_param)),
        link(translation(:discuss), "https://discuss.bikeindex.org")
      ]
    end

    def standard_items(organization:, current_user:, controller_name:, action_name:,
      unregistered_parking_notification:, is_dropdown:)
      render_disabled = !is_dropdown
      show_overview_dashboard = organization.overview_dashboard? ||
        (controller_name == "dashboard" && action_name == "index")
      show_bulk_import = organization.show_bulk_import? || controller_name == "bulk_imports"

      items = []

      if show_overview_dashboard
        items << link("#{organization.short_name} dashboard",
          routes.organization_dashboard_index_path(organization_id: organization.to_param))
        items << divider
      end

      items.concat(registration_items(organization, controller_name, action_name, render_disabled))
      items.concat(add_bike_items(organization, controller_name, action_name,
        unregistered_parking_notification, show_bulk_import))
      items << divider

      items.concat(feature_items(organization, render_disabled))
      items.concat(admin_items(organization, current_user, additional_divider: additional_divider?(organization)))
      items << divider unless is_dropdown && !current_user&.superuser?

      items
    end

    def additional_divider?(organization)
      %w[bike_stickers hot_sheet csv_exports graduated_notifications model_audits].any? do |slug|
        organization.enabled?(slug)
      end
    end

    def registration_items(organization, controller_name, action_name, render_disabled)
      on_registrations_path = controller_name == "registrations" && action_name == "index"
      items = [
        link(translation(:org_bikes, org_name: organization.short_name),
          routes.organization_registrations_path(organization_id: organization.to_param),
          active: on_registrations_path)
      ]

      if organization.enabled?("impound_bikes")
        items << link(translation(:impounded_bikes),
          routes.organization_impound_records_path(organization_id: organization.to_param),
          secondary: true, match_controller: true)
      end

      if organization.enabled?("show_partial_registrations")
        items << link(translation(:incomplete_registrations),
          routes.incompletes_organization_bikes_path(organization.to_param), secondary: true)
      elsif render_disabled && !organization.bike_shop?
        items << {type: :disabled, label: translation(:incomplete_registrations), secondary: true}
      end

      if organization.enabled?("bike_search")
        items << link(translation(:multi_search),
          routes.multi_search_organization_registrations_path(organization.to_param), secondary: true)
      end

      if organization.enabled?("show_recoveries")
        items << link(translation(:recoveries),
          routes.recoveries_organization_bikes_path(organization.to_param), secondary: true)
      end

      items
    end

    def add_bike_items(organization, controller_name, action_name,
      unregistered_parking_notification, show_bulk_import)
      new_bike_with_parking_notification = controller_name == "bikes" &&
        action_name == "new" && unregistered_parking_notification.present?
      new_bike_active = controller_name == "bikes" && action_name == "new" &&
        !new_bike_with_parking_notification

      items = [link(translation(:add_a_bike),
        routes.new_organization_bike_path(organization.to_param), active: new_bike_active)]

      divider_below = show_bulk_import || organization.lightspeed_or_broken_lightspeed? ||
        organization.enabled?("parking_notifications")
      items << divider if divider_below

      if show_bulk_import
        bulk_label = organization.ascend_or_broken_ascend? ? translation(:ascend_imports) : translation(:bulk_imports)
        items << link(bulk_label,
          routes.organization_bulk_imports_path(organization_id: organization.to_param),
          match_controller: true)
      end

      if organization.lightspeed_or_broken_lightspeed?
        items << link(translation(:lightspeed_integration_panel),
          routes.lightspeed_interface_path(organization_id: organization.id))
      end

      if organization.enabled?("parking_notifications")
        items << link(translation(:parking_notifications),
          routes.organization_parking_notifications_path(organization_id: organization.to_param))
        items << link(translation(:parking_notification_unregistered),
          routes.new_organization_bike_path(organization.to_param, parking_notification: true),
          secondary: true, active: new_bike_with_parking_notification)
      end

      items
    end

    def feature_items(organization, render_disabled)
      items = []

      if organization.enabled?("bike_stickers")
        items << link(translation(:registration_stickers),
          routes.organization_stickers_path(organization_id: organization.to_param),
          match_controller: true)
      elsif render_disabled
        items << {type: :disabled, label: translation(:registration_stickers), secondary: false}
      end

      if organization.enabled?("hot_sheet")
        items << link(translation(:stolen_hot_sheet),
          routes.organization_hot_sheet_path(organization_id: organization.to_param))
      end

      if organization.enabled?("csv_exports")
        items << link(translation(:exports),
          routes.organization_exports_path(organization_id: organization.to_param),
          match_controller: true)
      end

      if organization.enabled?("graduated_notifications")
        items << link(translation(:graduated_notifications),
          routes.organization_graduated_notifications_path(organization_id: organization.to_param),
          match_controller: true)
      end

      if organization.enabled?("model_audits")
        items << link(translation(:model_audits),
          routes.organization_model_audits_path(organization_id: organization.to_param),
          match_controller: true)
      end

      if organization.impound_claims?
        items << link(translation(:impounded_claims),
          routes.organization_impound_claims_path(organization_id: organization.to_param),
          match_controller: true)
      end

      items
    end

    def admin_items(organization, current_user, additional_divider:)
      return [] unless current_user&.admin_of?(organization) || current_user&.superuser?

      items = []
      items << divider if additional_divider
      items << link(translation(:manage_users),
        routes.organization_users_path(organization_id: organization.to_param), match_controller: true)

      if organization.enabled?("impound_bikes")
        items << link(translation(:manage_impounding, org_name: organization.short_name),
          routes.edit_organization_manage_impounding_path(organization_id: organization.to_param))
      end

      items << link(translation(:org_profile, org_name: organization.short_name),
        routes.organization_manage_path(organization_id: organization.to_param))
      items << link(translation(:org_locations, org_name: organization.short_name),
        routes.locations_organization_manage_path(organization_id: organization.to_param))

      if organization.enabled?("customize_emails")
        items << link(translation(:custom_emails),
          routes.organization_emails_path(organization_id: organization.to_param), match_controller: true)
      elsif organization.enabled?("organization_stolen_message")
        items << link(translation(:stolen_message),
          routes.edit_organization_email_path("organization_stolen_message", organization_id: organization.to_param))
      end

      if organization.enabled?("hot_sheet")
        items << link(translation(:stolen_hot_sheet_configuration),
          routes.edit_organization_hot_sheet_path(organization_id: organization.to_param))
      end

      items
    end

    def super_admin_items(organization, current_user)
      return [] unless current_user&.superuser?

      [{type: :super_admin_link,
        label: translation(:super_admin_view, org_name: organization.short_name),
        path: routes.admin_organization_path(organization)}]
    end

    #
    # private below here
    #

    def link(label, path, secondary: false, active: :auto, match_controller: false)
      {type: :link, label:, path:, secondary:, active:, match_controller:}
    end

    def divider
      {type: :divider}
    end

    def translation(key, **interpolations)
      I18n.t(key, scope: "shared.organized_menu_items", **interpolations)
    end

    def routes
      Rails.application.routes.url_helpers
    end

    conceal :ambassador_items, :standard_items, :registration_items, :add_bike_items,
      :feature_items, :admin_items, :super_admin_items, :additional_divider?,
      :link, :divider, :translation, :routes
  end
end
