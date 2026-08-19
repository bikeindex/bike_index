# frozen_string_literal: true

module PageBlock
  module UserAlerts
    module UnfinishedRegistration
      # Links back into the register flow, which reopens the registration where it was left
      class Component < ApplicationComponent
        def initialize(b_param:, current_user: nil)
          @b_param = b_param
          @current_user = current_user
        end

        # The alert outlives the registration finishing elsewhere (another tab, the
        # confirmation email), so the b_param has the final say - passed the user it
        # would otherwise load, since this runs on every page render
        def render?
          @b_param&.unfinished_registration?(@current_user || @b_param.creator)
        end

        def call
          render(UI::Alerts::Base::Component.new) { alert_text }
        end

        private

        # No manufacturer to name once the one step 1 named has been destroyed
        def alert_text
          manufacturer = @b_param.mnfg_name
          key = manufacturer.blank? ? ".not_registered_yet_html" : ".not_registered_yet_manufacturer_html"

          translation(key, manufacturer:, cycle_type: @b_param.type,
            finish_link: link_to(translation(".finish_the_required_steps"),
              register_path(b_param_token: @b_param.id_token), class: "twlink-underlined"))
        end
      end
    end
  end
end
