# frozen_string_literal: true

module Pages
  module MyAccount
    module PosRegistrationMatches
      module Show
        class Component < ApplicationComponent
          def initialize(bike:, pos_bike:, pos_registration_match:)
            @bike = bike
            @pos_bike = pos_bike
            @pos_registration_match = pos_registration_match
          end

          private

          def bike_type = @pos_bike.type

          def shop_name = @pos_bike.creation_organization&.short_name

          def different_email? = @pos_registration_match.different_email?

          # Obscured, since whoever has the token's email may not be the owner
          def other_email = EmailNormalizer.obfuscate(@bike.user&.email)

          def registrations
            if different_email?
              [[translation(".registered_when_it_was_bought"), @pos_bike],
                [translation(".registered_by", other_email:), @bike]]
            else
              [[translation(".registered_when_you_bought_it"), @pos_bike], [translation(".your_registration"), @bike]]
            end
          end

          def answer_path
            if different_email?
              pos_registration_match_path(@pos_registration_match.token)
            else
              my_account_pos_registration_match_path(@pos_registration_match)
            end
          end
        end
      end
    end
  end
end
