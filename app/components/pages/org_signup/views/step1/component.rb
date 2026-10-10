# frozen_string_literal: true

module Pages
  module OrgSignup
    module Views
      module Step1
        class Component < ApplicationComponent
          def initialize(organization_signup:, current_user: nil)
            @organization_signup = organization_signup
            @current_user = current_user
          end

          private

          def existing_organization = @current_user&.organizations&.first

          def kind_entries
            Organization.user_creatable_kinds.map { |kind| {value: kind, label: kind_label(kind)} }
          end

          def kind_label(kind)
            case kind
            when "bike_shop" then translation(".kind_bike_shop")
            when "bike_advocacy" then translation(".kind_bike_advocacy")
            when "law_enforcement" then translation(".kind_law_enforcement")
            when "school" then translation(".kind_school")
            when "bike_manufacturer" then translation(".kind_bike_manufacturer")
            when "software" then translation(".kind_software")
            when "property_management" then translation(".kind_property_management")
            when "municipality" then translation(".kind_municipality")
            else translation(".kind_other")
            end
          end

          def form_data
            {turbo: true, form_persist_key_value: "organization-signup-start-#{@organization_signup.id_token}",
             controller: "autofocus form-persist register--retry ui--forms--turnstile",
             **UI::Forms::Turnstile::Component.form_data(user: @current_user),
             action: "input->form-persist#save input->ui--forms--turnstile#update submit->form-persist#clear"}
          end
        end
      end
    end
  end
end
