# frozen_string_literal: true

module SharedBlocks
  module UserAlerts
    module PhoneWaitingConfirmation
      # Opens the modal that takes the code texted to a phone the user added but
      # hasn't confirmed
      class Component < ApplicationComponent
        MODAL_ID = "confirm-phone-number"

        def initialize(user_phone:)
          @user_phone = user_phone
        end

        def render?
          @user_phone.present?
        end

        private

        def modal_title
          translation(".verify_number", phone_number: Phonifyer.display(@user_phone.phone))
        end
      end
    end
  end
end
