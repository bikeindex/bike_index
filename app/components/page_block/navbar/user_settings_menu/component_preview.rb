# frozen_string_literal: true

module PageBlock
  module Navbar
    module UserSettingsMenu
      # The reader is built rather than found, so every scenario renders on any database --
      # and no real person's email reaches a preview
      class ComponentPreview < ApplicationComponentPreview
        # organization_switcher reads the association through a query, which a built user's
        # answers nothing from, so this stands in for the chain it makes
        PreviewRoles = Struct.new(:roles) do
          def includes(*) = self

          def order(*) = self

          def filter_map(&block) = roles.filter_map(&block)
        end

        # @!group Organizations

        # The shortest the menu gets -- no switcher, and no divider above the account rows
        def no_organizations
          render_menu(0)
        end

        # The one rendered open: the group stacks them, and an open menu is absolutely
        # positioned, so a second would render over whatever follows it
        def one_organization
          render_menu(1, open: true)
        end

        # Viewing in one of them, so the row for it is the disabled one
        def three_organizations
          render_menu(3, viewing: 1)
        end
        # @endgroup

        private

        def render_menu(organization_count, viewing: nil, open: false)
          organizations = Array.new(organization_count) do |i|
            Organization.new(name: "Preview Organization #{i + 1}", short_name: "Preview #{i + 1}",
              slug: "preview-organization-#{i + 1}")
          end

          render_with_template(template: "page_block/navbar/user_settings_menu/component_preview/menu",
            locals: {user: built_user(organizations), open:,
                     current_organization: viewing && organizations[viewing]})
        end

        def built_user(organizations)
          roles = organizations.map { |organization| OrganizationRole.new(organization:) }

          User.new(email: "preview@bikeindex.org").tap do |user|
            user.define_singleton_method(:organization_roles) { PreviewRoles.new(roles) }
          end
        end
      end
    end
  end
end
