# frozen_string_literal: true

# Returns the canonical organization menu item data — the same payload regardless
# of how the menu is being rendered (sidebar vs. dropdown) or which page is current.
# Cached per [organization, user]; the component handles per-request concerns
# (dropdown filtering, active-link resolution).
#
# Item shapes:
#   {type: :divider}
#   {type: :disabled, label:, secondary:} # component drops these in dropdown
#   {type: :link, label:, path:, secondary:, active:}
#
# The component appends a trailing divider (for non-ambassador orgs, unless
# rendering as a dropdown for a non-superuser) and a super_admin_link
# (for superusers).
#
# `active:` is one of:
#   :auto                                  - template uses active_link helper
#   :match_controller                      - template uses active_link with match_controller: true
#   :on_registrations_index                - component computes from current request
#   :on_bikes_new                          - "
#   :on_bikes_new_with_parking_notification - "
module OrganizedServices
  module MenuItems
    extend Functionable

    # UpdateOrganizationAssociationsJob touches every member user when an org
    # changes, so user.cache_key_with_version covers both per-user changes
    # and org-feature changes.
    def for(organization:, current_user:)
      return [] if organization.nil?

      key = ["organized_menu_items_v1", organization.id, current_user&.cache_key_with_version]
      Rails.cache.fetch(key) do
        build_items(organization, current_user)
      end
    end

    def build_items(organization, current_user)
      organization.ambassador? ? ambassador_items(organization) : standard_items(organization, current_user)
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
        items << dashboard_link(organization)
        items << divider
      end

      items.concat(registration_items(organization))
      items.concat(add_bike_items(organization))
      items << divider

      items.concat(feature_items(organization))
      items.concat(admin_items(organization, current_user, additional_divider: additional_divider?(organization)))

      items
    end

    # Public helpers for the component to inject route-specific overrides
    # (so the menu still shows the dashboard / bulk-imports link when the
    # user is on those pages, even if the org doesn't have the feature).
    def dashboard_link(organization)
      link("#{organization.short_name} dashboard",
        routes.organization_dashboard_index_path(organization_id: organization.to_param))
    end

    def bulk_import_link(organization)
      bulk_label = organization.ascend_or_broken_ascend? ? translation(:ascend_imports) : translation(:bulk_imports)
      link(bulk_label,
        routes.organization_bulk_imports_path(organization_id: organization.to_param),
        active: :match_controller)
    end

    #
    # private below here
    #

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
          secondary: true, active: :match_controller)
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

      items << bulk_import_link(organization) if organization.show_bulk_import?

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

      items << if organization.enabled?("bike_stickers")
        link(translation(:registration_stickers),
          routes.organization_stickers_path(organization_id: organization.to_param),
          active: :match_controller)
      else
        {type: :disabled, label: translation(:registration_stickers), secondary: false}
      end

      if organization.enabled?("hot_sheet")
        items << link(translation(:stolen_hot_sheet),
          routes.organization_hot_sheet_path(organization_id: organization.to_param))
      end

      if organization.enabled?("csv_exports")
        items << link(translation(:exports),
          routes.organization_exports_path(organization_id: organization.to_param),
          active: :match_controller)
      end

      if organization.enabled?("graduated_notifications")
        items << link(translation(:graduated_notifications),
          routes.organization_graduated_notifications_path(organization_id: organization.to_param),
          active: :match_controller)
      end

      if organization.enabled?("model_audits")
        items << link(translation(:model_audits),
          routes.organization_model_audits_path(organization_id: organization.to_param),
          active: :match_controller)
      end

      if organization.impound_claims?
        items << link(translation(:impounded_claims),
          routes.organization_impound_claims_path(organization_id: organization.to_param),
          active: :match_controller)
      end

      items
    end

    def admin_items(organization, current_user, additional_divider:)
      return [] unless current_user&.admin_of?(organization) || current_user&.superuser?

      items = []
      items << divider if additional_divider
      items << link(translation(:manage_users),
        routes.organization_users_path(organization_id: organization.to_param), active: :match_controller)

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
          routes.organization_emails_path(organization_id: organization.to_param), active: :match_controller)
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

    def link(label, path, secondary: false, active: :auto)
      {type: :link, label:, path:, secondary:, active:}
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

    conceal :build_items, :ambassador_items, :standard_items, :registration_items,
      :add_bike_items, :feature_items, :admin_items, :additional_divider?,
      :link, :divider, :translation, :routes
  end
end
