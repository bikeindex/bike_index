# frozen_string_literal: true

module PageBlock
  module Navbar
    module UserSettingsMenu
      # Each scenario searches out a real user with that many memberships, rather than one
      # deliberate account -- so an arbitrary real person, and their email, in production
      class ComponentPreview < ApplicationComponentPreview
        # The org sidebar's rendering, where the switcher is what varies
        # @!group Dropdown

        # The shortest the menu gets -- no switcher, and no divider above the account rows
        def no_organizations
          render_menu(0, "user outside an organization")
        end

        def one_organization
          render_menu(1, "user in one organization")
        end

        def three_organizations
          render_menu(3, "user in three organizations")
        end
        # @endgroup

        # The navbar's rendering, inside the bar it's styled by -- primary_header_nav.scss
        # scopes the submenu to .primary-header-nav, and page-block--navbar is what opens it
        # @display legacy_stylesheet true
        def navbar
          with_user(1, "user in one organization") do |user|
            render_with_template(template: "page_block/navbar/user_settings_menu/component_preview/navbar",
              locals: {user:})
          end
        end

        private

        def render_menu(count, needed)
          with_user(count, needed) do |user|
            render(PageBlock::Navbar::UserSettingsMenu::Component.new(current_user: user,
              current_user_or_unconfirmed_user: user, dropdown: true, name: user.email)) { user.email }
          end
        end

        # Lookbook is mounted unconstrained, so the count has to stay behind the guard --
        # over a production-sized users table it's a seq scan
        def with_user(count, needed)
          return production_notice("user") if Rails.env.production?

          user = user_with_organizations(count)
          return missing_notice(needed) if user.blank?

          yield(user)
        end

        def user_with_organizations(count)
          User.left_joins(:organization_roles).group("users.id")
            .having("count(organization_roles.id) = ?", count).order("users.id asc").first
        end
      end
    end
  end
end
