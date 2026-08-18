# frozen_string_literal: true

# The organization menu api/v3/me serves to API clients, cached per
# [organization, user]. OrganizedServices::SidebarMenu is what the site's own
# sidebar renders from; both build on OrganizedServices::OrganizationMenuLinks,
# which owns every path and feature gate.
#
# Item shapes:
#   {type: :divider}
#   {type: :disabled, label:, secondary:}
#   {type: :link, label:, path:, secondary:, match:, matching_controllers:}
#
# `match:` and `matching_controllers:` are UI::ActiveLink's, which resolves them
# in the browser. Nothing here depends on which page is current.
module OrganizedServices
  module UserMenuItems
    extend Functionable

    # UpdateOrganizationAssociationsJob touches every member user when an org
    # changes, so user.cache_key_with_version covers both per-user changes
    # and org-feature changes.
    def for(organization:, current_user:)
      return [] if organization.nil? || current_user.nil?

      Rails.cache.fetch(["organized_menu_items_v3", organization.id, current_user.cache_key_with_version]) do
        build_items(organization, current_user)
      end
    end

    #
    # private below here
    #

    def build_items(organization, current_user)
      links = OrganizationMenuLinks.for(organization)

      if organization.ambassador?
        ambassador_items(organization, links)
      else
        standard_items(organization, current_user, links)
      end
    end

    def ambassador_items(organization, links)
      [
        link(links[:ambassador_dashboard], translation(:org_dashboard, org_name: organization.short_name)),
        link(links[:ambassador_resources], translation(:resources)),
        link(links[:ambassador_getting_started], translation(:getting_started)),
        link(links[:multi_search], translation(:multi_search), ignore_enabled: true),
        link(links[:discuss], translation(:discuss))
      ]
    end

    def standard_items(organization, current_user, links)
      items = []

      if links[:dashboard][:enabled]
        items << link(links[:dashboard], "#{organization.short_name} dashboard", match: :path)
        items << divider
      end

      items.concat(registration_items(organization, links))
      items.concat(add_bike_items(organization, links))
      items << divider

      items.concat(feature_items(links))
      items.concat(admin_items(organization, current_user, links,
        additional_divider: additional_divider?(organization)))

      items
    end

    def additional_divider?(organization)
      %w[bike_stickers hot_sheet csv_exports graduated_notifications model_audits].any? do |slug|
        organization.enabled?(slug)
      end
    end

    def registration_items(organization, links)
      incompletes = if links[:incompletes][:enabled]
        link(links[:incompletes], translation(:incomplete_registrations), secondary: true)
      elsif !organization.bike_shop?
        {type: :disabled, label: translation(:incomplete_registrations), secondary: true}
      end

      [link(links[:registrations], translation(:org_bikes, org_name: organization.short_name)),
        link(links[:impound_records], translation(:impounded_bikes), secondary: true),
        incompletes,
        link(links[:multi_search], translation(:multi_search), secondary: true),
        link(links[:recoveries], translation(:recoveries), secondary: true)].compact
    end

    # Both add-a-bike links are organized/bikes#new, told apart by the parking_notification
    # param — so they match on the full path rather than on the page they share
    def add_bike_items(organization, links)
      items = [link(links[:add_bike], translation(:add_a_bike))]

      divider_below = links[:bulk_imports][:enabled] || links[:lightspeed][:enabled] ||
        links[:parking_notifications][:enabled]
      items << divider if divider_below

      bulk_label = organization.ascend_or_broken_ascend? ? translation(:ascend_imports) : translation(:bulk_imports)

      items.concat([link(links[:bulk_imports], bulk_label),
        link(links[:lightspeed], translation(:lightspeed_integration_panel)),
        link(links[:parking_notifications], translation(:parking_notifications)),
        link(links[:unregistered_notification], translation(:parking_notification_unregistered),
          secondary: true)].compact)
    end

    def feature_items(links)
      stickers = link(links[:stickers], translation(:registration_stickers)) ||
        {type: :disabled, label: translation(:registration_stickers), secondary: false}

      [stickers,
        link(links[:hot_sheet], translation(:stolen_hot_sheet)),
        link(links[:exports], translation(:exports)),
        link(links[:graduated_notifications], translation(:graduated_notifications)),
        link(links[:model_audits], translation(:model_audits)),
        link(links[:impound_claims], translation(:impounded_claims))].compact
    end

    def admin_items(organization, current_user, links, additional_divider:)
      return [] unless current_user.admin_of?(organization) || current_user.superuser?

      emails = link(links[:emails], translation(:custom_emails)) ||
        link(links[:stolen_message], translation(:stolen_message))

      [(divider if additional_divider),
        link(links[:manage_users], translation(:manage_users)),
        link(links[:manage_impounding], translation(:manage_impounding, org_name: organization.short_name)),
        link(links[:org_profile], translation(:org_profile, org_name: organization.short_name)),
        link(links[:org_locations], translation(:org_locations, org_name: organization.short_name)),
        emails,
        link(links[:hot_sheet_configuration], translation(:stolen_hot_sheet_configuration)),
        link(links[:registration_sequences], translation(:manage_registration_sequences))].compact
    end

    # An ambassador organization reaches multi_search without the feature the standard
    # menu gates it on, so its row asks for the link regardless
    def link(entry, label, secondary: false, match: nil, ignore_enabled: false)
      return nil unless entry[:enabled] || ignore_enabled

      {type: :link, label:, path: entry[:path], secondary:, match: match || entry[:match],
       matching_controllers: entry[:matching_controllers]}
    end

    def divider
      {type: :divider}
    end

    def translation(key, **interpolations)
      I18n.t(key, scope: "shared.organized_menu_items", **interpolations)
    end

    conceal :build_items, :ambassador_items, :standard_items, :registration_items,
      :add_bike_items, :feature_items, :admin_items, :additional_divider?,
      :link, :divider, :translation
  end
end
