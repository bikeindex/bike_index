# frozen_string_literal: true

module Integrations
  module Shopify
    # A bike shop's store sells tubes and helmets too - a labeled serial in the sale's notes
    # is what marks a line item as a bike worth registering
    module OrderParser
      extend Functionable

      Registration = Data.define(:serial, :line_item) do
        def manufacturer = line_item&.dig("vendor").presence || "Unknown"

        def frame_model = line_item&.dig("title")

        def quantity = line_item&.dig("quantity") || 1
      end

      def registerable?(order)
        return false if order.blank? || order["test"]
        return false if order["cancelled_at"].present?

        owner_email(order).present?
      end

      def owner_email(order)
        order["email"].presence || order.dig("customer", "email").presence
      end

      def registrations(order)
        return [] if order.blank?

        line_item_registrations(order) + note_registrations(order)
      end

      #
      # private below here
      #

      def line_item_registrations(order)
        line_items(order).flat_map do |line_item|
          SerialParser.serials_in_attributes(line_item["properties"])
            .map { Registration.new(serial: it, line_item:) }
        end
      end

      # An order note names no line item, so it only resolves to a product when the sale has
      # exactly one - a multi-item sale registers the serial with an unknown manufacturer
      def note_registrations(order)
        line_items = line_items(order)
        claimed = line_item_registrations(order).map(&:serial)
        serials = SerialParser.serials_in(order["note"]) +
          SerialParser.serials_in_attributes(order["note_attributes"])

        (serials.uniq - claimed).map do |serial|
          Registration.new(serial:, line_item: (line_items.one? ? line_items.first : nil))
        end
      end

      def line_items(order)
        order["line_items"].is_a?(Array) ? order["line_items"] : []
      end

      conceal :line_item_registrations, :note_registrations, :line_items
    end
  end
end
