# frozen_string_literal: true

module Atoms
  module Serial
    # Every serial state, rendered against in-memory bikes so nothing is written
    # to the database. The hidden states need a viewer who can see the serial, so
    # they pass lookbook_user (a superuser).
    # @label Serial
    class ComponentPreview < ApplicationComponentPreview
      # @!group Variants
      # @param serial text "Serial to render"
      def default(serial: "FFF333")
        render(Atoms::Serial::Component.new(bike: preview_bike(serial_number: serial)))
      end

      # @label unknown serial
      def unknown
        render(Atoms::Serial::Component.new(bike: preview_bike(serial_number: "unknown")))
      end

      # @label made without a serial
      def made_without_serial
        bike = preview_bike(serial_number: "made_without_serial", made_without_serial: true)
        render(Atoms::Serial::Component.new(bike:))
      end

      # @label hidden, with the reason why
      def hidden
        render(Atoms::Serial::Component.new(bike: hidden_bike))
      end

      # @label hidden, reason skipped
      def hidden_skip_explanation
        render(Atoms::Serial::Component.new(bike: hidden_bike, skip_explanation: true))
      end

      # @label hidden, shown to a viewer who may see it
      def hidden_authorized
        render(Atoms::Serial::Component.new(bike: hidden_bike, user: lookbook_user))
      end

      # @label hidden, shown to a viewer who may see it, reason skipped
      def hidden_authorized_skip_explanation
        render(Atoms::Serial::Component.new(bike: hidden_bike, user: lookbook_user, skip_explanation: true))
      end

      # @label no serial (renders nothing)
      def blank
        render(Atoms::Serial::Component.new(bike: ::Bike.new))
      end
      # @!endgroup

      private

      def preview_bike(**attributes)
        ::Bike.new(cycle_type: :bike, **attributes)
      end

      # Impounded is what makes a serial hidden - tandem so the reason reads distinctly
      def hidden_bike
        preview_bike(serial_number: "FFF333", cycle_type: :tandem, status: :status_impounded)
      end
    end
  end
end
