# frozen_string_literal: true

module PageBlock
  module UserAlerts
    module UnfinishedRegistration
      # Links back into the register flow, which reopens the registration wherever it was
      # left - including on the e-vehicle rules it never acknowledged
      class Component < ApplicationComponent
        def initialize(b_param:)
          @b_param = b_param
        end

        # The alert outlives the registration finishing elsewhere (another tab, the
        # confirmation email), so the b_param has the final say
        def render?
          @b_param&.unfinished_registration?
        end
      end
    end
  end
end
