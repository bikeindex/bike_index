# frozen_string_literal: true

module Pages
  module Registrations
    module Show
      module StolenDetails
        # Theft details for a stolen bike — mirrors the legacy show page's stolen block
        class Component < ApplicationComponent
          def initialize(bike:, current_user: nil)
            @bike = bike
            @current_user = current_user
          end

          def render?
            @bike.status_stolen? && stolen_record.present?
          end

          private

          def stolen_record
            @stolen_record ||= @bike.current_stolen_record
          end

          # Shown only when the owner's phone-visibility settings permit this viewer
          def owner_phone
            stolen_record.phone if @bike.phoneable_by?(@current_user)
          end
        end
      end
    end
  end
end
