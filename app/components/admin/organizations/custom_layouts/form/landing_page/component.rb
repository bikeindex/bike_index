# frozen_string_literal: true

module Admin
  module Organizations
    module CustomLayouts
      module Form
        module LandingPage
          # Editing an organization's landing page markup, with the images it can reference.
          class Component < ApplicationComponent
            def initialize(organization:, landing_page:, suggested_button_hover: nil)
              @organization = organization
              @landing_page = landing_page
              @suggested_button_hover = suggested_button_hover
            end

            private

            def form_url
              admin_organization_custom_layout_path(organization_id: @organization.to_param, id: "landing_page")
            end

            def version_history_path
              admin_paper_trail_versions_path(search_item_type: "OrganizationLandingPage",
                search_item_id: @landing_page.id, period: "all")
            end

            def hover_param = "&button_hover=#{@suggested_button_hover.delete_prefix("#")}"
          end
        end
      end
    end
  end
end
