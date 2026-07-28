# frozen_string_literal: true

module Register
  module Step1
    # Step 1 of the registration flow: the quick-start form
    class Component < ApplicationComponent
      def initialize(b_param:)
        @b_param = b_param
      end

      private

      def cycle_type
        @b_param.type
      end

      # Stale once step 1 was submitted - the confirmation email went out then
      def confirmation_email_pending?
        @b_param.params["partial_email_sent_to"].blank?
      end
    end
  end
end
