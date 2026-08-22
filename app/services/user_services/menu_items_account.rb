# frozen_string_literal: true

# The account menu: the reader's account links, the organizations they can switch between,
# and logout. PageBlock::Navbar::UserSettingsMenu renders it as the navbar's gear submenu,
# PageBlock::Navbar::AccountMenu as the org sidebar's dropdown.
#
# Its rows are ComponentStructs::Items'.
module UserServices
  module MenuItemsAccount
    extend Functionable

    OPENS = [:down, :up].freeze

    # A reader in dozens of organizations would otherwise push logout off the menu
    SWITCHER_ORGANIZATIONS = 5

    # opens: which way the menu unrolls from its trigger, so it reads outward from there either
    # way. The switcher holds its own order regardless: leaving the organization behind leads it
    def for(user:, current_organization: nil, opens: :down)
      raise ArgumentError, "opens: must be one of #{OPENS}" unless OPENS.include?(opens)

      account = account_rows(user)
      switcher = organization_switcher(user, current_organization:)

      sections = (opens == :up) ? [[logout_row], switcher, account.reverse] : [account, switcher, [logout_row]]
      sections.reject(&:empty?).inject { |rows, section| rows + [items.divider] + section }
    end

    #
    # private below here
    #

    # Whichever organization they're already viewing has nowhere to go, so it's a label
    # rather than a link
    def organization_switcher(user, current_organization: nil)
      organizations = switchable_organizations(user)
      # A superuser can be viewing one they're no member of, which is still where they are
      # and still something to leave
      organizations += [current_organization] if current_organization.present? &&
        organizations.exclude?(current_organization)
      return [] if organizations.none?

      [without_organization(current_organization)] + organizations.map { |organization|
        if organization == current_organization
          items.disabled(translation(:viewing_org, org_name: organization.name))
        else
          items.link(translation(:switch_to_org, org_name: organization.name),
            routes.organization_root_path(organization_id: organization.to_param))
        end
      }
    end

    # navUserSettingLink is how the signed-in email is read off a page -- by
    # .claude/skills/frontend-screenshots' identity gate, among others
    def account_rows(user)
      [items.link(translation(:your_registrations), routes.my_account_path),
        marketplace_messages(user),
        # The row stays current across every step of the flow, which all live under it
        items.link(translation(:register_a_new_bike), routes.register_path, section: true),
        items.link(translation(:user_settings, user_email: user.email), routes.edit_my_account_path,
          id: "navUserSettingLink", data: {email: user.email})].compact
    end

    # The one row that isn't somewhere to go
    def logout_row
      items.link(translation(:logout), routes.goodbye_path, danger: true)
    end

    def marketplace_messages(user)
      return nil unless MarketplaceMessage.any_for_user?(user)

      items.link(translation(:marketplace_messages), routes.my_account_messages_path)
    end

    # In the user's own order, so the switcher is the same five every time it's opened
    # rather than whatever the planner returns
    def switchable_organizations(user)
      OrganizationRole.ordered_for(user).includes(:organization)
        .filter_map(&:organization).first(SWITCHER_ORGANIZATIONS)
    end

    # organization_id=false is what clears the one held in the session. The homepage is where
    # that lands from inside the organization interface; page-block--navbar-switch-no-organization
    # points it at the current page anywhere else
    def without_organization(current_organization)
      return items.disabled(translation(:viewing_without_org)) if current_organization.blank?

      items.link(translation(:view_without_org), routes.root_url(organization_id: false),
        data: {controller: "page-block--navbar-switch-no-organization"})
    end

    def items = ComponentStructs::Items

    def translation(key, **interpolations)
      I18n.t(key, scope: "shared.menu_items_account", **interpolations)
    end

    def routes
      Rails.application.routes.url_helpers
    end

    conceal :organization_switcher, :account_rows, :logout_row, :marketplace_messages,
      :switchable_organizations, :without_organization, :items, :translation, :routes
  end
end
