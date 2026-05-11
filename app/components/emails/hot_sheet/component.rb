# frozen_string_literal: true

module Emails
  module HotSheet
    class Component < ApplicationComponent
      def initialize(hot_sheet:, stolen_records:)
        @hot_sheet = hot_sheet
        @stolen_records = stolen_records
      end

      private

      def organization
        @hot_sheet.organization
      end

      def organization_address
        organization.default_address_record
      end

      def search_location
        parts = [organization_address&.city]
        parts += [organization_address&.country&.name] unless organization_address&.country&.united_states?
        parts.reject(&:blank?).join(", ")
      end

      def thumb_url(bike)
        bike.thumb_path || bike.stock_photo_url || "https://files.bikeindex.org/email_assets/bike_photo_placeholder.png"
      end

      def thumb_placeholder?(bike)
        bike.thumb_path.blank? && bike.stock_photo_url.blank?
      end

      def bike_link(bike)
        bike_url(bike, organization_id: organization.to_param, sign_in_if_not: true)
      end

      def stolen_at_label(stolen_record)
        if stolen_record.date_stolen.to_date == @hot_sheet.sheet_date
          "Today"
        elsif stolen_record.date_stolen.to_date == @hot_sheet.sheet_date.yesterday
          "Yesterday"
        end
      end
    end
  end
end
