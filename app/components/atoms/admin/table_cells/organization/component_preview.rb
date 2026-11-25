# frozen_string_literal: true

module Atoms
  module Admin
    module TableCells
      module Organization
        class ComponentPreview < ApplicationComponentPreview
          # @!group Organization Variants

          def with_organization
            render(Atoms::Admin::TableCells::Organization::Component.new(organization:))
          end

          def with_organization_id
            render(Atoms::Admin::TableCells::Organization::Component.new(organization_id: ::Organization.deleted.first.id))
          end

          def with_search_link
            render(Atoms::Admin::TableCells::Organization::Component.new(organization:, search_url: admin_organizations_path(organization_id: organization.id), render_search: true))
          end

          def missing_organization
            render(Atoms::Admin::TableCells::Organization::Component.new(organization_id: 99999999))
          end

          private

          def organization
            ::Organization.friendly_find "brakebills"
          end
        end
      end
    end
  end
end
