# frozen_string_literal: true

module Pages
  module Register
    module Views
      module Step2
        # Step 2 of the registration flow: the bike details form
        class Component < ApplicationComponent
          def initialize(b_param:, flow:, current_user: nil)
            @b_param = b_param
            @flow = flow
            @current_user = current_user
          end

          private

          def cycle_type
            @b_param.type
          end

          # The theft its owner reports next, in the stolen report wizard - so these steps start that report
          def before_render
            @stolen_frame = !@flow.single_page? && BikeServices::Register.report_in_wizard?(@b_param)
          end

          def stolen_frame? = @stolen_frame
        end
      end
    end
  end
end
