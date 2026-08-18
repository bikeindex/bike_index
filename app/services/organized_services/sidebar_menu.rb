# frozen_string_literal: true

# The organization sidebar's menu, grouped the way the design lays it out:
# collapsible groups that own their children, rather than the flat list of links
# and dividers OrganizedServices::UserMenuItems returns for the API. Both build on
# OrganizedServices::OrganizationMenuLinks, which owns every path and feature gate.
#
# Item shapes:
#   {type: :divider}
#   {type: :group, key:, label:, icon:, children: [...]}
#   {type: :link, label:, path:, icon:, match:, routes:}
#   {type: :disabled, label:}
#
# A group whose children are all gated off doesn't render at all. `key` is what
# the Stimulus controller opens and closes, and what the component matches the
# current page against to decide which group starts open.
#
# `match:` is UI::ActiveLink's, but PageBlock::OrgSidebar resolves it itself -- it
# needs the answer before the rows render, to open the group holding the current
# page. `routes:` is what a controller-granularity match compares against, its own
# and any second controller the section spans.
module OrganizedServices
  module SidebarMenu
    extend Functionable

    def for(organization:, current_user:)
      return [] if organization.nil? || current_user.nil?

      Rails.cache.fetch(["organized_sidebar_menu_v2", organization.id, current_user.cache_key_with_version]) do
        build_items(organization, current_user)
      end
    end

    #
    # private below here
    #

    # Sections rather than a flat list, so a section gated off entirely takes the
    # divider above it with it
    def build_items(organization, current_user)
      links = OrganizationMenuLinks.for(organization)
      return ambassador_items(organization, links) if organization.ambassador?

      admin = current_user.admin_of?(organization)

      [[registrations_group(organization, links),
        link(links[:add_bike], translation(:add_a_bike), icon: "plus-circle")],
        [impounded_group(organization, links),
          parking_group(links),
          bulk_group(organization, links),
          link(links[:lightspeed], translation(:lightspeed_integration_panel), icon: "lightspeed"),
          messaging_link(links, admin),
          link(links[:model_audits], translation(:model_audits), icon: "bolt"),
          link(links[:graduated_notifications], translation(:graduated_notifications), icon: "graduation-cap"),
          link(links[:hot_sheet], translation(:stolen_hot_sheet), icon: "clipboard"),
          # The overview dashboard is what the design's Reports row describes
          link(links[:dashboard], translation(:reports), icon: "bar-chart")],
        [settings_group(organization, links, admin)]]
        .map(&:compact).reject(&:empty?)
        .inject { |items, section| items + [divider] + section }
    end

    # Organized::BaseController bars an ambassador organization from every controller
    # below except registrations#multi_search, so its menu is its own list rather than
    # the standard one with rows that only redirect
    def ambassador_items(organization, links)
      [
        link(links[:ambassador_dashboard], translation(:org_dashboard, org_name: organization.short_name),
          icon: "bar-chart"),
        link(links[:ambassador_resources], translation(:resources), icon: "list"),
        link(links[:ambassador_getting_started], translation(:getting_started), icon: "graduation-cap"),
        link(links[:multi_search], translation(:multi_search), icon: "searcher", ignore_enabled: true),
        link(links[:discuss], translation(:discuss), icon: "chat")
      ]
    end

    def registrations_group(organization, links)
      children = [
        link(links[:registrations], translation(:search_registrations)),
        link(links[:incompletes], translation(:incomplete_registrations)),
        link(links[:multi_search], translation(:multi_search)),
        link(links[:recoveries], translation(:recoveries)),
        link(links[:stickers], translation(:registration_stickers))
      ]

      group(:registrations, translation(:org_registrations, org_name: organization.short_name), "bike", children)
    end

    # Managing impounding is the settings group's, which is where the org's other
    # configuration lives -- this group is for the vehicles themselves. Add an Impounded
    # Vehicle is in the design with nothing to link to, since organized routes no
    # impound_records#new, so it renders greyed rather than the menu losing the row
    def impounded_group(organization, links)
      return nil unless organization.enabled?("impound_bikes")

      children = [
        link(links[:impound_records], translation(:search_impounded_vehicles)),
        link(links[:impound_claims], translation(:impounded_claims)),
        disabled(translation(:add_an_impounded_vehicle))
      ]

      group(:impounded, translation(:impounded_vehicles), "impound", children)
    end

    def parking_group(links)
      children = [
        link(links[:parking_notifications], translation(:search_parking_notifications)),
        link(links[:unregistered_notification], translation(:parking_notification_unregistered))
      ]

      group(:parking, translation(:parking_notifications_group), "map-pin", children)
    end

    def bulk_group(organization, links)
      import_label = organization.ascend_or_broken_ascend? ? translation(:ascend_imports) : translation(:bulk_imports)
      children = [
        link(links[:bulk_imports], import_label),
        link(links[:exports], translation(:exports))
      ]

      group(:bulk, translation(:bulk_import_and_export), "import-export", children)
    end

    # Organized::EmailsController only lets a member at #show, so this needs the admin
    # check the settings group gets from being admin-only. Without customize_emails there
    # is no index to send them to, and the stolen message is the one email they can edit
    def messaging_link(links, admin)
      return nil unless admin

      link(links[:emails], translation(:messaging), icon: "chat") ||
        link(links[:stolen_message], translation(:stolen_message), icon: "chat")
    end

    def settings_group(organization, links, admin)
      return nil unless admin

      children = [
        link(links[:org_profile], translation(:org_profile, org_name: organization.short_name)),
        link(links[:org_locations], translation(:org_locations, org_name: organization.short_name)),
        link(links[:manage_users], translation(:manage_users)),
        link(links[:manage_impounding], translation(:impounding)),
        link(links[:hot_sheet_configuration], translation(:stolen_hot_sheet)),
        link(links[:registration_sequences], translation(:manage_registration_sequences))
      ]

      group(:settings, translation(:org_settings, org_name: organization.short_name), "gear", children)
    end

    def group(key, label, icon, children)
      present = children.compact
      return nil if present.none? { |child| child[:type] == :link }

      {type: :group, key:, label:, icon:, children: present}
    end

    # An ambassador organization reaches multi_search without the feature the standard
    # menu gates it on, so its row asks for the link regardless
    def link(entry, label, icon: nil, ignore_enabled: false)
      return nil unless entry[:enabled] || ignore_enabled

      {type: :link, label:, path: entry[:path], icon:, match: entry[:match], routes: link_routes(entry)}
    end

    # Recognized here rather than by the component, which would pay a route recognition
    # per row on every render; this payload is built once per [organization, user]
    def link_routes(entry)
      return [] unless entry[:match].in?(%i[controller controller_action])

      recognized = Rails.application.routes.recognize_path(entry[:path])
      route = (entry[:match] == :controller) ? recognized[:controller] : "#{recognized[:controller]}##{recognized[:action]}"
      [route, *entry[:matching_controllers]]
    rescue ActionController::RoutingError
      entry[:matching_controllers]
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

    conceal :build_items, :ambassador_items, :registrations_group, :impounded_group, :parking_group,
      :bulk_group, :messaging_link, :settings_group, :group, :link, :link_routes, :disabled,
      :divider, :translation
  end
end
