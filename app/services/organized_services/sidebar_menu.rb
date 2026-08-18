# frozen_string_literal: true

# The organization sidebar's menu, grouped the way the design lays it out:
# collapsible groups that own their children, rather than the flat list of links
# and dividers OrganizedServices::UserMenuItems returns for the API.
#
# Item shapes:
#   {type: :divider}
#   {type: :group, key:, label:, icon:, children: [...]}
#   {type: :link, label:, path:, active:}
#   {type: :disabled, label:}
#
# A group whose children are all gated off doesn't render at all. `key` is what
# the Stimulus controller opens and closes, and what the component matches the
# current page against to decide which group starts open.
#
# `active:` names how the current page is recognized, since nothing here knows what
# it is -- PageBlock::OrgSidebar::Component resolves them:
#   :auto                       - the path
#   :match_controller           - the path's controller
#   :on_registrations_index     - its controller and action
#   :on_bikes_new               - the path and its query params
#   :on_registration_sequences  - also matches the pages controller
module OrganizedServices
  module SidebarMenu
    extend Functionable

    def for(organization:, current_user:)
      return [] if organization.nil? || current_user.nil?

      Rails.cache.fetch(["organized_sidebar_menu_v1", organization.id, current_user.cache_key_with_version]) do
        build_items(organization, current_user)
      end
    end

    #
    # private below here
    #

    # Sections rather than a flat list, so a section gated off entirely takes the
    # divider above it with it
    def build_items(organization, current_user)
      return ambassador_items(organization) if organization.ambassador?

      admin = current_user.admin_of?(organization)

      [[registrations_group(organization), add_bike_link(organization)],
        [impounded_group(organization),
          parking_group(organization),
          bulk_group(organization),
          lightspeed_link(organization),
          messaging_link(organization, admin),
          model_audits_link(organization),
          graduated_link(organization),
          hot_sheet_link(organization),
          reports_link(organization)],
        [settings_group(organization, admin)]]
        .map(&:compact).reject(&:empty?)
        .inject { |items, section| items + [divider] + section }
    end

    # Organized::BaseController bars an ambassador organization from every controller
    # below except registrations#multi_search, so its menu is its own list rather than
    # the standard one with rows that only redirect
    def ambassador_items(organization)
      [
        link(translation(:org_dashboard, org_name: organization.short_name),
          routes.organization_ambassador_dashboard_path(organization_id: organization.to_param),
          icon: "bar-chart"),
        link(translation(:resources),
          routes.resources_organization_ambassador_dashboard_path(organization_id: organization.to_param),
          icon: "list"),
        link(translation(:getting_started),
          routes.getting_started_organization_ambassador_dashboard_path(organization_id: organization.to_param),
          icon: "graduation-cap"),
        link(translation(:multi_search),
          routes.multi_search_organization_registrations_path(organization_id: organization.to_param),
          icon: "searcher"),
        link(translation(:discuss), "https://discuss.bikeindex.org", icon: "chat")
      ]
    end

    def registrations_group(organization)
      children = [
        link(translation(:search_registrations),
          routes.organization_registrations_path(organization_id: organization.to_param),
          active: :on_registrations_index),
        enabled_link(organization, "show_partial_registrations", translation(:incomplete_registrations),
          routes.incompletes_organization_bikes_path(organization.to_param)),
        enabled_link(organization, "bike_search", translation(:multi_search),
          routes.multi_search_organization_registrations_path(organization.to_param)),
        enabled_link(organization, "show_recoveries", translation(:recoveries),
          routes.recoveries_organization_bikes_path(organization.to_param)),
        enabled_link(organization, "bike_stickers", translation(:registration_stickers),
          routes.organization_stickers_path(organization_id: organization.to_param), active: :match_controller)
      ]

      group(:registrations, translation(:org_registrations, org_name: organization.short_name), "bike", children)
    end

    def add_bike_link(organization)
      link(translation(:add_a_bike), routes.new_organization_bike_path(organization.to_param),
        icon: "plus-circle", active: :on_bikes_new)
    end

    # Managing impounding is the settings group's, which is where the org's other
    # configuration lives -- this group is for the vehicles themselves. Add an Impounded
    # Vehicle is in the design with nothing to link to, since organized routes no
    # impound_records#new, so it renders greyed rather than the menu losing the row
    def impounded_group(organization)
      return nil unless organization.enabled?("impound_bikes")

      children = [
        link(translation(:search_impounded_vehicles),
          routes.organization_impound_records_path(organization_id: organization.to_param),
          active: :match_controller),
        (if organization.impound_claims?
           link(translation(:impounded_claims),
             routes.organization_impound_claims_path(organization_id: organization.to_param),
             active: :match_controller)
         end),
        disabled(translation(:add_an_impounded_vehicle))
      ]

      group(:impounded, translation(:impounded_vehicles), "impound", children)
    end

    def parking_group(organization)
      return nil unless organization.enabled?("parking_notifications")

      children = [
        link(translation(:search_parking_notifications),
          routes.organization_parking_notifications_path(organization_id: organization.to_param)),
        link(translation(:parking_notification_unregistered),
          routes.new_organization_bike_path(organization.to_param, parking_notification: true))
      ]

      group(:parking, translation(:parking_notifications_group), "map-pin", children)
    end

    def bulk_group(organization)
      import_label = organization.ascend_or_broken_ascend? ? translation(:ascend_imports) : translation(:bulk_imports)
      children = [
        (if organization.show_bulk_import?
           link(import_label, routes.organization_bulk_imports_path(organization_id: organization.to_param),
             active: :match_controller)
         end),
        enabled_link(organization, "csv_exports", translation(:exports),
          routes.organization_exports_path(organization_id: organization.to_param), active: :match_controller)
      ]

      group(:bulk, translation(:bulk_import_and_export), "import-export", children)
    end

    # The route redirects to posintegration, which reads the id rather than the slug
    def lightspeed_link(organization)
      return nil unless organization.lightspeed_or_broken_lightspeed?

      link(translation(:lightspeed_integration_panel),
        routes.lightspeed_interface_path(organization_id: organization.id), icon: "lightspeed")
    end

    # Organized::EmailsController only lets a member at #show, so this needs the admin
    # check the settings group gets from being admin-only. Without customize_emails there
    # is no index to send them to, and the stolen message is the one email they can edit
    def messaging_link(organization, admin)
      return nil unless admin

      if organization.enabled?("customize_emails")
        link(translation(:messaging), routes.organization_emails_path(organization_id: organization.to_param),
          icon: "chat", active: :match_controller)
      elsif organization.enabled?("organization_stolen_message")
        link(translation(:stolen_message),
          routes.edit_organization_email_path("organization_stolen_message", organization_id: organization.to_param),
          icon: "chat")
      end
    end

    def model_audits_link(organization)
      return nil unless organization.enabled?("model_audits")

      link(translation(:model_audits), routes.organization_model_audits_path(organization_id: organization.to_param),
        icon: "bolt", active: :match_controller)
    end

    def graduated_link(organization)
      return nil unless organization.enabled?("graduated_notifications")

      link(translation(:graduated_notifications),
        routes.organization_graduated_notifications_path(organization_id: organization.to_param),
        icon: "graduation-cap", active: :match_controller)
    end

    def hot_sheet_link(organization)
      return nil unless organization.enabled?("hot_sheet")

      link(translation(:stolen_hot_sheet), routes.organization_hot_sheet_path(organization_id: organization.to_param),
        icon: "clipboard")
    end

    # The overview dashboard is what the design's Reports row describes
    def reports_link(organization)
      return nil unless organization.overview_dashboard?

      link(translation(:reports),
        routes.organization_dashboard_index_path(organization_id: organization.to_param),
        icon: "bar-chart", active: :match_controller)
    end

    def settings_group(organization, admin)
      return nil unless admin

      children = [
        link(translation(:org_profile, org_name: organization.short_name),
          routes.organization_manage_path(organization_id: organization.to_param)),
        link(translation(:org_locations, org_name: organization.short_name),
          routes.locations_organization_manage_path(organization_id: organization.to_param)),
        link(translation(:manage_users),
          routes.organization_users_path(organization_id: organization.to_param), active: :match_controller),
        enabled_link(organization, "impound_bikes", translation(:impounding),
          routes.edit_organization_manage_impounding_path(organization_id: organization.to_param)),
        enabled_link(organization, "hot_sheet", translation(:stolen_hot_sheet),
          routes.edit_organization_hot_sheet_path(organization_id: organization.to_param)),
        enabled_link(organization, "registration_sequences", translation(:manage_registration_sequences),
          routes.organization_registration_sequences_path(organization_id: organization.to_param),
          active: :on_registration_sequences)
      ]

      group(:settings, translation(:org_settings, org_name: organization.short_name), "gear", children)
    end

    def group(key, label, icon, children)
      present = children.compact
      return nil if present.none? { |child| child[:type] == :link }

      {type: :group, key:, label:, icon:, children: present}
    end

    def link(label, path, icon: nil, active: :auto)
      {type: :link, label:, path:, icon:, active:}
    end

    def enabled_link(organization, feature, label, path, **options)
      link(label, path, **options) if organization.enabled?(feature)
    end

    def disabled(label)
      {type: :disabled, label:}
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

    conceal :build_items, :ambassador_items, :registrations_group, :add_bike_link, :impounded_group,
      :parking_group, :bulk_group, :lightspeed_link, :messaging_link, :model_audits_link, :graduated_link,
      :hot_sheet_link, :reports_link, :settings_group, :group, :link, :enabled_link, :disabled,
      :divider, :translation, :routes
  end
end
