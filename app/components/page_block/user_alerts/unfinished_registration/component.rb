# frozen_string_literal: true

module PageBlock
  module UserAlerts
    module UnfinishedRegistration
      # Links back into the register flow, which reopens the registration where it was left
      class Component < ApplicationComponent
        def initialize(b_param:)
          @b_param = b_param
        end

        # The alert outlives the registration finishing elsewhere (another tab, the
        # confirmation email), so the b_param has the final say
        def render?
          @b_param&.unfinished_registration?
        end

        def call
          render(UI::Alerts::Base::Component.new) do
            translation(".not_registered_yet_html", cycle_type: @b_param.type,
              finish_link: link_to(translation(".finish_the_required_steps"),
                register_path(b_param_token: @b_param.id_token), class: "twlink"))
          end
        end
      end
    end
  end
end
