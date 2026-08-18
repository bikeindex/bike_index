# frozen_string_literal: true

# Every destination an organization's menu can point at, in one place: where it goes,
# whether this organization reaches it, and how a link to it recognizes the current page.
#
# The two menus built from this each own their own labels, order and structure --
# OrganizedServices::UserMenuItems is the flat list api/v3/me serves, and
# OrganizedServices::SidebarMenu the grouped one PageBlock::OrgSidebar renders. What they
# can't own separately is a route, a feature gate or a match granularity, which is what
# drifts when the same destination is declared twice.
#
# Entry shape: {path:, enabled:, match:, matching_controllers:}
module OrganizedServices
  module OrganizationMenuLinks
    extend Functionable

    def for(organization)
      slug = organization.to_param

      {
        registrations: entry(routes.organization_registrations_path(organization_id: slug),
          match: :controller_action),
        incompletes: entry(routes.incompletes_organization_bikes_path(slug),
          enabled: organization.enabled?("show_partial_registrations")),
        multi_search: entry(routes.multi_search_organization_registrations_path(slug),
          enabled: organization.enabled?("bike_search")),
        recoveries: entry(routes.recoveries_organization_bikes_path(slug),
          enabled: organization.enabled?("show_recoveries")),
        stickers: entry(routes.organization_stickers_path(organization_id: slug),
          enabled: organization.enabled?("bike_stickers"), match: :controller),
        add_bike: entry(routes.new_organization_bike_path(slug), match: :full_path),
        unregistered_notification: entry(routes.new_organization_bike_path(slug, parking_notification: true),
          enabled: organization.enabled?("parking_notifications"), match: :full_path),
        impound_records: entry(routes.organization_impound_records_path(organization_id: slug),
          enabled: organization.enabled?("impound_bikes"), match: :controller),
        impound_claims: entry(routes.organization_impound_claims_path(organization_id: slug),
          enabled: organization.impound_claims?, match: :controller),
        parking_notifications: entry(routes.organization_parking_notifications_path(organization_id: slug),
          enabled: organization.enabled?("parking_notifications")),
        bulk_imports: entry(routes.organization_bulk_imports_path(organization_id: slug),
          enabled: organization.show_bulk_import?, match: :controller),
        exports: entry(routes.organization_exports_path(organization_id: slug),
          enabled: organization.enabled?("csv_exports"), match: :controller),
        # The route redirects to posintegration, which reads the id rather than the slug
        lightspeed: entry(routes.lightspeed_interface_path(organization_id: organization.id),
          enabled: organization.lightspeed_or_broken_lightspeed?),
        emails: entry(routes.organization_emails_path(organization_id: slug),
          enabled: organization.enabled?("customize_emails"), match: :controller),
        stolen_message: entry(
          routes.edit_organization_email_path("organization_stolen_message", organization_id: slug),
          enabled: organization.enabled?("organization_stolen_message")
        ),
        model_audits: entry(routes.organization_model_audits_path(organization_id: slug),
          enabled: organization.enabled?("model_audits"), match: :controller),
        graduated_notifications: entry(routes.organization_graduated_notifications_path(organization_id: slug),
          enabled: organization.enabled?("graduated_notifications"), match: :controller),
        hot_sheet: entry(routes.organization_hot_sheet_path(organization_id: slug),
          enabled: organization.enabled?("hot_sheet")),
        hot_sheet_configuration: entry(routes.edit_organization_hot_sheet_path(organization_id: slug),
          enabled: organization.enabled?("hot_sheet")),
        dashboard: entry(routes.organization_dashboard_index_path(organization_id: slug),
          enabled: organization.overview_dashboard?, match: :controller),
        manage_users: entry(routes.organization_users_path(organization_id: slug), match: :controller),
        manage_impounding: entry(routes.edit_organization_manage_impounding_path(organization_id: slug),
          enabled: organization.enabled?("impound_bikes")),
        org_profile: entry(routes.organization_manage_path(organization_id: slug)),
        org_locations: entry(routes.locations_organization_manage_path(organization_id: slug)),
        # Editing a page of a sequence is the same section of the menu, on its own controller
        registration_sequences: entry(routes.organization_registration_sequences_path(organization_id: slug),
          enabled: organization.enabled?("registration_sequences"), match: :controller,
          matching_controllers: ["organized/registration_sequence_pages"]),
        ambassador_dashboard: entry(routes.organization_ambassador_dashboard_path(organization_id: slug)),
        ambassador_resources: entry(routes.resources_organization_ambassador_dashboard_path(organization_id: slug)),
        ambassador_getting_started: entry(
          routes.getting_started_organization_ambassador_dashboard_path(organization_id: slug)
        ),
        discuss: entry("https://discuss.bikeindex.org")
      }
    end

    #
    # private below here
    #

    def entry(path, enabled: true, match: :path, matching_controllers: [])
      {path:, enabled:, match:, matching_controllers:}
    end

    def routes
      Rails.application.routes.url_helpers
    end

    conceal :entry, :routes
  end
end
