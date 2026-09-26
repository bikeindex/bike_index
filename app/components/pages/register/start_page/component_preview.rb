# frozen_string_literal: true

module Pages
  module Register
    module StartPage
      # The flow's opening form. Every register preview renders against real
      # organizations and posts to the live register endpoints, so they're gated out
      # of production, where submitting one would start a real registration
      class ComponentPreview < ApplicationComponentPreview
        def default
          start_page
        end

        # Arrived on an organization's registration link
        def with_organization
          start_page(creation_organization_id: lookbook_organization&.id)
        end

        # Step 1 is only revisitable once submitted, so this is where "start over" appears
        def returned_from_step_2
          start_page(manufacturer_id: ::Manufacturer.frame_makers.first&.id, cycle_type: "e-scooter")
        end

        # Framed on an organization's landing page
        def embedded
          start_page(embed: true, creation_organization_id: lookbook_organization&.id)
        end

        def embedded_with_button_color
          start_page(embed: true, button_color: "#c9a227", creation_organization_id: lookbook_organization&.id)
        end

        # The organization switch that asks for both steps at once
        def single_page
          start_page(single_page: true)
        end

        # The organization's own registration fields, under its heading
        def single_page_with_organization
          start_page(single_page: true, creation_organization_id: lookbook_organization&.id)
        end

        private

        def start_page(embed: false, button_color: nil, single_page: false, **bike)
          return production_notice("registration") if Rails.env.production?

          b_param = ::BParam.new(origin: "register_flow",
            params: {bike: {owner_email: lookbook_user&.email}.merge(bike).compact}.as_json)
          render(Pages::Register::StartPage::Component.new(b_param:, current_user: lookbook_user, embed:, button_color:,
            flow: ::BikeServices::Register.flow(b_param, sequence: ::BikeServices::Register.registration_sequence(b_param),
              single_page:)))
        end
      end
    end
  end
end
