# frozen_string_literal: true

module Pages
  module Register
    module StartPage
      # The page the flow opens on - its progress, heading, errors and the form itself -
      # around whichever fields step 1 asks for: its own, or both steps'
      class Component < ApplicationComponent
        # Which page opens the flow is read off the steps, so the switch is decided in one place
        def self.opening_page(steps:, **)
          component = steps.include?("2") ? Pages::Register::Step1::Component : Pages::Register::StepCombined::Component
          component.new(steps:, **)
        end

        def initialize(b_param:, steps:, organization:, current_user: nil, subtitle: nil, embed: false,
          skip_heading: false)
          @b_param = b_param
          @steps = steps
          @organization = organization
          @current_user = current_user
          @subtitle = subtitle
          @embed = embed
          @skip_heading = skip_heading
        end

        private

        def single_page? = @steps.exclude?("2")

        # The step is still asking what's being registered, so the heading can't name the
        # type. Framed, the page around it already says whose registration this is
        def heading_text
          return translation(".register_your_vehicle") if @embed || @organization.blank?

          translation(".register_your_vehicle_with_org", org_name: @organization.short_name)
        end

        # What a frame can't have: a Turbo submission, which Turbo would render back inside it
        # (the target is ignored unless it names an iframe); autofocus, which scrolls the
        # embedding page down to the frame on load; and form-persist, whose localStorage is
        # partitioned per embedding site and blocked outright in Safari
        def form_options
          return {data: {turbo: false}, html: {target: "_top"}} if @embed

          # The single page's form holds step 2's fields too
          {data: {turbo: true, form_persist_key_value: "register-#{single_page? ? "combined" : "start"}-#{@b_param.id_token}",
                  controller: ["autofocus form-persist register--retry ui--forms--turnstile",
                    (Pages::Register::Step2Fields::Component::FORM_CONTROLLERS if single_page?)].compact.join(" "),
                  **UI::Forms::Turnstile::Component.form_data(user: @current_user),
                  action: ["input->form-persist#save hw-combobox:selection->form-persist#save " \
                    "input->ui--forms--turnstile#update submit->form-persist#clear",
                    (Pages::Register::Step2Fields::Component::FORM_ACTIONS if single_page?)].compact.join(" ")}}
        end
      end
    end
  end
end
