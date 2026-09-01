# frozen_string_literal: true

# The organization menu, grouped the way the design lays it out: collapsible groups
# that own their children. PageBlock::Navbar::OrgSidebar renders it and api/v3/me serves it,
# cached per [organization, user].
#
# Its rows are ComponentStructs::Shapes'.
module UserServices
  module MenuItemsOrg
    extend Functionable

    # Nothing here depends on which page is current
    def for(organization:, current_user:, old_register_view: false)
      return [] if organization.nil? || current_user.nil?

      Rails.cache.fetch(["menu_items_org_v1", organization, current_user,
        old_register_view]) do
        build_items(organization, current_user, old_register_view)
      end
    end

    #
    # private below here
    #

    # Sections rather than a flat list, so a section gated off entirely takes the
    # divider above it with it
    def build_items(organization, current_user, old_register_view)
      sections = organization_sections(organization, current_user, old_register_view) +
        [[super_admin_link(organization, current_user)]]

      sections.map(&:compact).reject(&:empty?)
        .inject { |rows, section| rows + [ComponentStructs::Shapes.divider] + section }
    end

    def organization_sections(organization, current_user, old_register_view)
      return [ambassador_items(organization)] if organization.ambassador?

      admin = current_user.admin_of?(organization)

      [[registrations_group(organization), add_bike_link(organization, old_register_view)],
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
    end

    # Leaves the organization interface behind, so it's a section of its own rather than
    # one of the organization's rows
    def super_admin_link(organization, current_user)
      return nil unless current_user.superuser?

      ComponentStructs::Shapes.link(translation(:in_super_admin, org_name: organization.short_name),
        routes.admin_organization_path(organization.to_param), icon: "super-admin")
    end

    # Organized::BaseController bars an ambassador organization from every controller
    # below except registrations#multi_search, so its menu is its own list rather than
    # the standard one with rows that only redirect
    def ambassador_items(organization)
      [
        ComponentStructs::Shapes.link(translation(:org_dashboard, org_name: organization.short_name),
          routes.organization_ambassador_dashboard_path(organization_id: organization.to_param),
          icon: "bar-chart"),
        ComponentStructs::Shapes.link(translation(:resources),
          routes.resources_organization_ambassador_dashboard_path(organization_id: organization.to_param),
          icon: "list"),
        ComponentStructs::Shapes.link(translation(:getting_started),
          routes.getting_started_organization_ambassador_dashboard_path(organization_id: organization.to_param),
          icon: "graduation-cap"),
        ComponentStructs::Shapes.link(translation(:multi_search),
          routes.multi_search_organization_registrations_path(organization_id: organization.to_param),
          icon: "searcher"),
        ComponentStructs::Shapes.link(translation(:discuss), "https://discuss.bikeindex.org", icon: "chat")
      ]
    end

    def registrations_group(organization)
      children = [
        ComponentStructs::Shapes.link(translation(:search_registrations),
          routes.organization_registrations_path(organization_id: organization.to_param)),
        enabled_link(organization, "show_partial_registrations", translation(:incomplete_registrations),
          routes.incompletes_organization_bikes_path(organization.to_param)),
        enabled_link(organization, "bike_search", translation(:multi_search),
          routes.multi_search_organization_registrations_path(organization.to_param)),
        enabled_link(organization, "show_recoveries", translation(:recoveries),
          routes.recoveries_organization_bikes_path(organization.to_param)),
        enabled_link(organization, "bike_stickers", translation(:registration_stickers),
          routes.organization_stickers_path(organization_id: organization.to_param), section: true)
      ]

      ComponentStructs::Shapes.group(:registrations,
        translation(:org_registrations, org_name: organization.short_name), "bike", children)
    end

    # The old view puts this row on organized/bikes#new, which the parking notification row
    # also links, so the param is what tells them apart
    def add_bike_link(organization, old_register_view)
      path = if old_register_view
        routes.new_organization_bike_path(organization.to_param)
      else
        routes.new_organization_registration_path(organization.to_param)
      end
      ComponentStructs::Shapes.link(translation(:add_a_bike), path, icon: "plus-circle",
        match_params: {parking_notification: nil})
    end

    # Managing impounding is the settings group's, which is where the org's other
    # configuration lives -- this group is for the vehicles themselves. Add an Impounded
    # Vehicle is in the design with nothing to link to, since organized routes no
    # impound_records#new, so it renders greyed rather than the menu losing the row
    def impounded_group(organization)
      return nil unless organization.enabled?("impound_bikes")

      children = [
        ComponentStructs::Shapes.link(translation(:search_impounded_vehicles),
          routes.organization_impound_records_path(organization_id: organization.to_param),
          section: true),
        (if organization.impound_claims?
           ComponentStructs::Shapes.link(translation(:impounded_claims),
             routes.organization_impound_claims_path(organization_id: organization.to_param),
             section: true)
         end),
        ComponentStructs::Shapes.disabled(translation(:add_an_impounded_vehicle))
      ]

      ComponentStructs::Shapes.group(:impounded, translation(:impounded_vehicles), "impound", children)
    end

    def parking_group(organization)
      return nil unless organization.enabled?("parking_notifications")

      children = [
        ComponentStructs::Shapes.link(translation(:search_parking_notifications),
          routes.organization_parking_notifications_path(organization_id: organization.to_param)),
        ComponentStructs::Shapes.link(translation(:parking_notification_unregistered),
          routes.new_organization_bike_path(organization.to_param, parking_notification: true),
          match_params: {parking_notification: true})
      ]

      ComponentStructs::Shapes.group(:parking, translation(:parking_notifications_group), "map-pin", children)
    end

    def bulk_group(organization)
      import_label = organization.ascend_or_broken_ascend? ? translation(:ascend_imports) : translation(:bulk_imports)
      children = [
        (if organization.show_bulk_import?
           ComponentStructs::Shapes.link(import_label,
             routes.organization_bulk_imports_path(organization_id: organization.to_param), section: true)
         end),
        enabled_link(organization, "csv_exports", translation(:exports),
          routes.organization_exports_path(organization_id: organization.to_param), section: true)
      ]

      ComponentStructs::Shapes.group(:bulk, translation(:bulk_import_and_export), "import-export", children)
    end

    # The route redirects to posintegration, which reads the id rather than the slug
    def lightspeed_link(organization)
      return nil unless organization.lightspeed_or_broken_lightspeed?

      ComponentStructs::Shapes.link(translation(:lightspeed_integration_panel),
        routes.lightspeed_interface_path(organization_id: organization.id), icon: "lightspeed")
    end

    # Organized::EmailsController only lets a member at #show, so this needs the admin
    # check the settings group gets from being admin-only. Without customize_emails there
    # is no index to send them to, and the stolen message is the one email they can edit
    def messaging_link(organization, admin)
      return nil unless admin

      if organization.enabled?("customize_emails")
        ComponentStructs::Shapes.link(translation(:messaging),
          routes.organization_emails_path(organization_id: organization.to_param), icon: "chat", section: true)
      elsif organization.enabled?("organization_stolen_message")
        ComponentStructs::Shapes.link(translation(:stolen_message),
          routes.edit_organization_email_path("organization_stolen_message", organization_id: organization.to_param),
          icon: "chat")
      end
    end

    def model_audits_link(organization)
      enabled_link(organization, "model_audits", translation(:model_audits),
        routes.organization_model_audits_path(organization_id: organization.to_param),
        icon: "bolt", section: true)
    end

    def graduated_link(organization)
      enabled_link(organization, "graduated_notifications", translation(:graduated_notifications),
        routes.organization_graduated_notifications_path(organization_id: organization.to_param),
        icon: "graduation-cap", section: true)
    end

    def hot_sheet_link(organization)
      enabled_link(organization, "hot_sheet", translation(:stolen_hot_sheet),
        routes.organization_hot_sheet_path(organization_id: organization.to_param), icon: "clipboard")
    end

    # The overview dashboard is what the design's Reports row describes, and the org's own
    # root renders it too
    def reports_link(organization)
      return nil unless organization.overview_dashboard?

      dashboard = routes.organization_dashboard_index_path(organization_id: organization.to_param)
      ComponentStructs::Shapes.link(translation(:reports), dashboard, icon: "bar-chart",
        match_paths: ["#{dashboard}/**", org_root(organization)])
    end

    def settings_group(organization, admin)
      return nil unless admin

      sequences = routes.organization_registration_sequences_path(organization_id: organization.to_param)
      children = [
        ComponentStructs::Shapes.link(translation(:org_profile, org_name: organization.short_name),
          routes.organization_manage_path(organization_id: organization.to_param)),
        ComponentStructs::Shapes.link(translation(:org_locations, org_name: organization.short_name),
          routes.locations_organization_manage_path(organization_id: organization.to_param)),
        ComponentStructs::Shapes.link(translation(:manage_users),
          routes.organization_users_path(organization_id: organization.to_param), section: true),
        enabled_link(organization, "impound_bikes", translation(:impounding),
          routes.edit_organization_manage_impounding_path(organization_id: organization.to_param)),
        enabled_link(organization, "hot_sheet", translation(:stolen_hot_sheet),
          routes.edit_organization_hot_sheet_path(organization_id: organization.to_param)),
        # Editing a page of a sequence is the same section of the menu, on a path of its own
        enabled_link(organization, "registration_sequences", translation(:registration_sequences), sequences,
          match_paths: ["#{sequences}/**", "#{org_root(organization)}/registration_sequence_pages/**"])
      ]

      ComponentStructs::Shapes.group(:settings,
        translation(:org_settings, org_name: organization.short_name), "gear", children)
    end

    def org_root(organization)
      routes.organization_root_path(organization.to_param)
    end

    def enabled_link(organization, feature, label, path, **options)
      ComponentStructs::Shapes.link(label, path, **options) if organization.enabled?(feature)
    end

    def translation(key, **interpolations)
      I18n.t(key, scope: "shared.menu_items_org", **interpolations)
    end

    def routes
      Rails.application.routes.url_helpers
    end

    conceal :build_items, :organization_sections, :super_admin_link, :ambassador_items,
      :registrations_group, :add_bike_link, :impounded_group,
      :parking_group, :bulk_group, :lightspeed_link, :messaging_link, :model_audits_link, :graduated_link,
      :hot_sheet_link, :reports_link, :settings_group, :org_root, :enabled_link, :translation, :routes
  end
end
