# frozen_string_literal: true

# Returns the canonical organization menu item data — the same payload regardless
# of how the menu is being rendered (sidebar vs. dropdown) or which page is current.
# Cached per [organization, user]; the component handles per-request concerns
# (dropdown filtering, active-link resolution).
#
# Item shapes:
#   {type: :divider}
#   {type: :trailing_divider}            # last divider; component drops it in dropdown for non-superusers
#   {type: :disabled, label:, secondary:} # component drops these in dropdown
#   {type: :link, label:, path:, secondary:, match_controller:, active:}
#   {type: :super_admin_link, label:, path:}
#
# `active:` is one of:
#   :auto                                  - component uses active_link helper
#   :on_registrations_index                - component computes from current request
#   :on_bikes_new                          - "
#   :on_bikes_new_with_parking_notification - "
module OrganizedServices
  module MenuItems
    extend Functionable

    CACHE_VERSION = "v1"
    CACHE_EXPIRES_IN = 1.hour

    def for(organization:, current_user:)
      return [] if organization.nil?

      Rails.cache.fetch(cache_key(organization, current_user), expires_in: CACHE_EXPIRES_IN) do
        build_items(organization, current_user)
      end
    end

    def cache_key(organization, current_user)
      [
        "organized_menu_items",
        CACHE_VERSION,
        organization.cache_key_with_version,
        current_user&.id,
        current_user&.superuser? || false,
        current_user&.admin_of?(organization) || false
      ]
    end

    def build_items(organization, current_user)
      base = organization.ambassador? ? ambassador_items(organization) : standard_items(organization, current_user)
      base + super_admin_items(organization, current_user)
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

    def standard_items(organization, current_user)
      items = []

      if organization.overview_dashboard?
        items << link("#{organization.short_name} dashboard",
          routes.organization_dashboard_index_path(organization_id: organization.to_param))
        items << divider
      end

      items.concat(registration_items(organization))
      items.concat(add_bike_items(organization))
      items << divider

      items.concat(feature_items(organization))
      items.concat(admin_items(organization, current_user, additional_divider: additional_divider?(organization)))
      items << {type: :trailing_divider}

      items
    end

    def additional_divider?(organization)
      %w[bike_stickers hot_sheet csv_exports graduated_notifications model_audits].any? do |slug|
        organization.enabled?(slug)
      end
    end

    def registration_items(organization)
      items = [
        link(translation(:org_bikes, org_name: organization.short_name),
          routes.organization_registrations_path(organization_id: organization.to_param),
          active: :on_registrations_index)
      ]

      if organization.enabled?("impound_bikes")
        items << link(translation(:impounded_bikes),
          routes.organization_impound_records_path(organization_id: organization.to_param),
          secondary: true, match_controller: true)
      end

      if organization.enabled?("show_partial_registrations")
        items << link(translation(:incomplete_registrations),
          routes.incompletes_organization_bikes_path(organization.to_param), secondary: true)
      elsif !organization.bike_shop?
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

    def add_bike_items(organization)
      items = [link(translation(:add_a_bike),
        routes.new_organization_bike_path(organization.to_param), active: :on_bikes_new)]

      divider_below = organization.show_bulk_import? || organization.lightspeed_or_broken_lightspeed? ||
        organization.enabled?("parking_notifications")
      items << divider if divider_below

      if organization.show_bulk_import?
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
          secondary: true, active: :on_bikes_new_with_parking_notification)
      end

      items
    end

    def feature_items(organization)
      items = []

      if organization.enabled?("bike_stickers")
        items << link(translation(:registration_stickers),
          routes.organization_stickers_path(organization_id: organization.to_param),
          match_controller: true)
      else
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

    conceal :build_items, :cache_key, :ambassador_items, :standard_items, :registration_items,
      :add_bike_items, :feature_items, :admin_items, :super_admin_items, :additional_divider?,
      :link, :divider, :translation, :routes
  end
end
