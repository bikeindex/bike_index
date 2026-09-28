# frozen_string_literal: true

module Pages
  module Register
    module Views
      module Step1
        # Step 1 of the registration flow: the quick-start form
        class Component < ApplicationComponent
          def initialize(b_param:, flow:, organization: nil, current_user: nil, embed: false,
            skip_heading: false, button_color: nil, button_hover_color: nil)
            @b_param = b_param
            @flow = flow
            @organization = organization
            @current_user = current_user
            @embed = embed
            @skip_heading = skip_heading
            @button_color = button_color
            @button_hover_color = button_hover_color
          end

          private

          def organization
            @organization ||= @b_param.creation_organization
          end

          # The step is still asking what's being registered, so the heading can't name the
          # type. Framed, the page around it already says whose registration this is
          def heading_text
            return translation(".register_your_vehicle") if @embed || organization.blank?

            translation(".register_your_vehicle_with_org", org_name: organization.short_name)
          end

          # What a frame can't have: a Turbo submission, which Turbo would render back inside it
          # (the target is ignored unless it names an iframe); autofocus, which scrolls the
          # embedding page down to the frame on load; and form-persist, whose localStorage is
          # partitioned per embedding site and blocked outright in Safari
          def form_options
            return {data: {turbo: false}, html: {target: "_top"}} if @embed

            {data: {turbo: true, controller: "autofocus form-persist register--retry ui--forms--turnstile",
                    form_persist_key_value: "register-start-#{@b_param.id_token}",
                    **UI::Forms::Turnstile::Component.form_data(user: @current_user),
                    action: "input->form-persist#save hw-combobox:selection->form-persist#save " \
                      "input->ui--forms--turnstile#update submit->form-persist#clear"}}
          end
        end
      end
    end
  end
end
