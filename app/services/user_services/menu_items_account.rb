# frozen_string_literal: true

# The organizations the reader can switch between, and their marketplace messages --
# the rows PageBlock::Navbar::UserSettingsMenu carries beyond its own.
#
# Item shapes are UserServices::MenuItemsOrg's, so the two menus read alike:
#   {type: :link, label:, path:, icon:, match:, matching_controllers:}
#   {type: :disabled, label:}
module UserServices
  module MenuItemsAccount
    extend Functionable

    # A reader in dozens of organizations would otherwise push logout off the menu
    SWITCHER_ORGANIZATIONS = 5

    # Its own section, which the caller sets off -- the two menus put it in different places.
    # Whichever they're already viewing has nowhere to go, so it's a label rather than a link
    def organization_switcher(user, current_organization: nil)
      organizations = switchable_organizations(user)
      # A superuser can be viewing one they're no member of, which is still where they are
      # and still something to leave
      organizations += [current_organization] if current_organization.present? &&
        organizations.exclude?(current_organization)
      return [] if organizations.none?

      [without_organization(current_organization)] + organizations.map { |organization|
        if organization == current_organization
          disabled(translation(:viewing_org, org_name: organization.name))
        else
          link(translation(:switch_to_org, org_name: organization.name),
            routes.organization_root_path(organization_id: organization.to_param))
        end
      }
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

    def link(label, path, icon: nil, match: :path, matching_controllers: [], **attributes)
      {type: :link, label:, path:, icon:, match:, matching_controllers:, **attributes}
    end

    # organization_id=false is what clears the one held in the session. The homepage is where
    # that lands from inside the organization interface; page-block--without-organization
    # points it at the current page anywhere else
    def without_organization(current_organization)
      return disabled(translation(:viewing_without_org)) if current_organization.blank?

      link(translation(:view_without_org), routes.root_url(organization_id: false),
        data: {controller: "page-block--without-organization"})
    end

    def disabled(label)
      {type: :disabled, label:}
    end

    def translation(key, **interpolations)
      I18n.t(key, scope: "shared.menu_items_account", **interpolations)
    end

    def routes
      Rails.application.routes.url_helpers
    end

    conceal :switchable_organizations, :without_organization, :link, :disabled, :translation, :routes
  end
end
