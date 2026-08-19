# frozen_string_literal: true

# The rows both account menus carry: the organizations the reader can switch between, and
# their marketplace messages. PageBlock::Navbar::SettingsMenu renders them in the gear
# dropdown and PageBlock::Navbar::OrgSidebar in its account block -- only one of the two is
# ever on a page, and they'd read as different menus if each named these itself.
#
# Item shapes, which each component renders its own way:
#   {type: :divider}
#   {label:, path:}
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
        {label: translation(:switch_to_org, org_name: organization.name),
         path: routes.organization_root_path(organization_id: organization.to_param)}
      } + [{type: :divider}]
    end

    def marketplace_messages(user)
      return nil unless MarketplaceMessage.any_for_user?(user)

      {label: translation(:marketplace_messages), path: routes.my_account_messages_path}
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

    def translation(key, **interpolations)
      I18n.t(key, scope: "shared.menu_items_account", **interpolations)
    end

    def routes
      Rails.application.routes.url_helpers
    end

    conceal :switchable_organizations, :translation, :routes
  end
end
