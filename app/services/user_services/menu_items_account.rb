# frozen_string_literal: true

# The organizations the reader can switch between, and their marketplace messages --
# the rows PageBlock::Navbar::SettingsMenu carries beyond its own.
#
# Item shapes are UserServices::MenuItemsOrg's, so one renderer takes either list:
#   {type: :divider}
#   {type: :link, label:, path:, icon:, match:, matching_controllers:}
module UserServices
  module MenuItemsAccount
    extend Functionable

    # A reader in dozens of organizations would otherwise push logout off the menu
    SWITCHER_ORGANIZATIONS = 5

    # Trailing divider included, so a reader in no organization takes it with them
    def organization_switcher(user)
      organizations = switchable_organizations(user)
      return [] if organizations.none?

      organizations.map { |organization|
        link(translation(:switch_to_org, org_name: organization.name),
          routes.organization_root_path(organization_id: organization.to_param))
      } + [divider]
    end

    def marketplace_messages(user)
      return nil unless MarketplaceMessage.any_for_user?(user)

      link(translation(:marketplace_messages), routes.my_account_messages_path)
    end

    #
    # private below here
    #

    # Ordered, so the switcher is the same five every time it's opened rather than
    # whatever the planner returns
    def switchable_organizations(user)
      user.organization_roles.includes(:organization).order(:id)
        .filter_map(&:organization).first(SWITCHER_ORGANIZATIONS)
    end

    def link(label, path, icon: nil, match: :path, matching_controllers: [])
      {type: :link, label:, path:, icon:, match:, matching_controllers:}
    end

    def divider
      {type: :divider}
    end

    def translation(key, **interpolations)
      I18n.t(key, scope: "shared.menu_items_account", **interpolations)
    end

    def routes
      Rails.application.routes.url_helpers
    end

    conceal :switchable_organizations, :link, :divider, :translation, :routes
  end
end
