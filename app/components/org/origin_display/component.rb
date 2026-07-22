# frozen_string_literal: true

module Org
  module OriginDisplay
    class Component < ApplicationComponent
      EXTENDED_DESCRIPTIONS = {
        "web" => "Registered with self registration process",
        "org reg" => "Registered by internal, organization member form",
        "landing page" => "Registration began with incomplete registration, via organization landing page",
        "bulk reg" => "Registered by spreadsheet import"
      }.freeze
      def initialize(creation_description:)
        @creation_description = creation_description
      end

      def render?
        @creation_description.present?
      end

      def call
        safe_join([label, render(UI::Tooltip::Component.new(text: origin_title))], " ")
      end

      private

      def label
        return "Unregistered Parking Notification" if unregistered_parking_notification?

        @creation_description
      end

      def origin_title
        if %w[Lightspeed Ascend].include?(@creation_description)
          "Automatically registered by bike shop point of sale (#{@creation_description} POS)"
        elsif unregistered_parking_notification?
          "Registered via the Unregistered Parking Notification flow"
        else
          EXTENDED_DESCRIPTIONS[@creation_description] || "Registered via #{@creation_description}"
        end
      end

      def unregistered_parking_notification?
        @creation_description == "creator unregistered parking notification"
      end
    end
  end
end
