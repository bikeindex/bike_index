# frozen_string_literal: true

module Pages
  module Register
    module Views
      module Step1
        # Step 1 of the registration flow: the quick-start form, which ends in its own submit
        # or, on the single page, step 2's fields
        class Component < ApplicationComponent
          # landing: in Pages::Register::Views::Landing's hero card, which supplies the shell
          def initialize(b_param:, flow:, organization: nil, current_user: nil, embed: false,
            landing: false, skip_heading: false, button_color: nil, button_hover_color: nil, motorized_review: false)
            @b_param = b_param
            @flow = flow
            @organization = organization
            @current_user = current_user
            @embed = embed
            @landing = landing
            @skip_heading = skip_heading
            @button_color = button_color
            @button_hover_color = button_hover_color
            @motorized_review = motorized_review
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

          # The landing page has its own h1, so the card's heading sits under it at the same size
          def heading_options = @landing ? {tag: :h2, html_class: "tw:text-2xl!"} : {}

          def subtitle
            translation(".just_the_essentials") unless @flow.single_page?
          end

          # What a frame can't have: a Turbo submission, which Turbo would render back inside it
          # (the target is ignored unless it names an iframe); autofocus, which scrolls the
          # embedding page down to the frame on load; and form-persist, whose localStorage is
          # partitioned per embedding site and blocked outright in Safari.
          # The landing page skips autofocus too, which would scroll past its hero
          def form_options
            return {data: {turbo: false}, html: {target: "_top"}} if @embed

            details = Pages::Register::Parts::Step2Fields::Component
            # Step 2's photo field is in a bare fields_for, whose multipart flag never reaches the form
            {multipart: @flow.single_page?,
             data: {turbo: true, form_persist_key_value: "register-#{@flow.single_page? ? "combined" : "start"}-#{@b_param.id_token}",
                    controller: "#{"autofocus " unless @landing}form-persist register--retry ui--forms--turnstile #{details::FORM_CONTROLLERS if @flow.single_page?}",
                    **UI::Forms::Turnstile::Component.form_data(user: @current_user),
                    action: "input->form-persist#save hw-combobox:selection->form-persist#save " \
                      "input->ui--forms--turnstile#update submit->form-persist#clear #{single_page_actions}"}}
          end

          # The electric checkbox and the owner's email share the single page's form, and change
          # what the submit leads to
          def single_page_actions
            return unless @flow.single_page?

            "#{Pages::Register::Parts::Step2Fields::Component::FORM_ACTIONS} input->register--status-fields#updateSubmitLabel"
          end
        end
      end
    end
  end
end
