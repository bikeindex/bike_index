# frozen_string_literal: true

module Pages
  module Register
    module StepCombined
      # Step 1 and step 2 on one page, for the switch that asks for the whole
      # registration at once. Its submission is step 1's, carrying step 2's fields
      class Component < ApplicationComponent
        def initialize(b_param:, steps:, current_user: nil, skip_heading: false, organization: nil)
          @b_param = b_param
          @steps = steps
          @current_user = current_user
          @skip_heading = skip_heading
          @organization = organization
        end

        private

        # Both steps' controllers, on the one form that holds both their fields
        def form_options
          {data: {turbo: true, form_persist_key_value: "register-combined-#{@b_param.id_token}",
                  controller: "autofocus form-persist register--status-fields register--organization " \
                    "register--retry ui--forms--turnstile",
                  **UI::Forms::Turnstile::Component.form_data(user: @current_user),
                  action: "input->form-persist#save hw-combobox:selection->form-persist#save " \
                    "hw-combobox:selection->register--status-fields#update " \
                    "register--organization:changed->register--status-fields#update " \
                    "input->ui--forms--turnstile#update submit->form-persist#clear"}}
        end

        def organization
          @organization ||= @b_param.creation_organization
        end
      end
    end
  end
end
