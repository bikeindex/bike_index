# frozen_string_literal: true

module PageBlock
  module Navbar
    module UserSettingsMenu
      class ComponentPreview < ApplicationComponentPreview
        # Each scenario searches out a real user with that many memberships, rather than one
        # deliberate account -- so an arbitrary real person, and their email, in production.
        # The switcher is capped at UserServices::MenuItemsAccount::SWITCHER_ORGANIZATIONS,
        # which spec/services pins; three is under it, so all three rows show
        # @!group Organizations

        # The shortest the menu gets -- no switcher, and no divider above the account rows
        def no_organizations
          render_menu(user_with_organizations(0), "user outside an organization")
        end

        def one_organization
          render_menu(user_with_organizations(1), "user in one organization")
        end

        def three_organizations
          render_menu(user_with_organizations(3), "user in three organizations")
        end
        # @endgroup

        private

        def render_menu(user, needed)
          return production_notice("user") if Rails.env.production?
          return missing_notice(needed) if user.blank?

          render(PageBlock::Navbar::UserSettingsMenu::Component.new(current_user: user,
            current_user_or_unconfirmed_user: user, name: user.email)) { user.email }
        end

        def user_with_organizations(count)
          return User.where.missing(:organization_roles).order(:id).first if count.zero?

          User.joins(:organization_roles).group("users.id").having("count(*) = ?", count)
            .order("users.id asc").first
        end
      end
    end
  end
end
