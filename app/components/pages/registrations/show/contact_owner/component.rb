# frozen_string_literal: true

module Pages
  module Registrations
    module Show
      module ContactOwner
        # "Contact the owner" message form for a stolen bike — mirrors the legacy
        # bikes/show contact block, revealing the form via Stimulus
        class Component < ApplicationComponent
          def initialize(bike:, current_user: nil, owner: false)
            @bike = bike
            @current_user = current_user
            @owner = owner
          end

          # Not shown to the owner — they don't contact themselves
          def render?
            !@owner && BikeServices::Displayer.display_contact_owner?(@bike, @current_user)
          end

          private

          def stolen_notification
            @stolen_notification ||= StolenNotification.new(bike: @bike)
          end

          # Logged-out viewers are sent to sign-in and returned with the form open
          def sign_in_redirect
            return if @current_user.present?

            new_session_path(return_to: registration_path(@bike, contact_owner: true))
          end

          # Shown only when the owner's phone-visibility settings permit this viewer
          def owner_phone
            return @owner_phone if defined?(@owner_phone)

            @owner_phone = @bike.current_stolen_record&.phone if @bike.phoneable_by?(@current_user)
          end
        end
      end
    end
  end
end
