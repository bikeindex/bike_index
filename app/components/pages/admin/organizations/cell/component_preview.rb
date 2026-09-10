# frozen_string_literal: true

module Pages
  module Admin
    module Organizations
      module Cell
        class ComponentPreview < ApplicationComponentPreview
          # @!group Organization Variants

          def with_organization
            render(Pages::Admin::Organizations::Cell::Component.new(organization:))
          end

          def with_organization_id
            render(Pages::Admin::Organizations::Cell::Component.new(organization_id: Organization.deleted.first.id))
          end

          def with_search_link
            render(Pages::Admin::Organizations::Cell::Component.new(organization:, search_url: admin_organizations_path(organization_id: organization.id), render_search: true))
          end

          def missing_organization
            render(Pages::Admin::Organizations::Cell::Component.new(organization_id: 99999999))
          end

          private

          def organization
            Organization.friendly_find "brakebills"
          end
        end
      end
    end
  end
end
