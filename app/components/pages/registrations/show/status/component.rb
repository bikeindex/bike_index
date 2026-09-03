# frozen_string_literal: true

module Pages
  module Registrations
    module Show
      module Status
        # The stolen/found/impounded/registered status badge.
        class Component < ApplicationComponent
          # override_to_for_sale: the marketplace preview, where the listing is still a draft
          def initialize(bike:, override_to_for_sale: false)
            @bike = bike
            @override_to_for_sale = override_to_for_sale
          end

          def call
            render(UI::Badge::Component.new(text: label, color:, indicator: true))
          end

          private

          def label
            if @bike.status_stolen?
              translation(".stolen")
            elsif @bike.status_found?
              translation(".found")
            elsif @bike.status_impounded?
              translation(".impounded")
            elsif @bike.unregistered_parking_notification?
              translation(".unregistered")
            elsif for_sale?
              translation(".for_sale")
            else
              translation(".not_stolen")
            end
          end

          def color
            return :error if @bike.status_stolen?
            return :warning if @bike.status_impounded? || @bike.unregistered_parking_notification?
            return :purple if for_sale?

            :success
          end

          def for_sale?
            @bike.status_with_owner? && (@override_to_for_sale || @bike.is_for_sale?)
          end
        end
      end
    end
  end
end
