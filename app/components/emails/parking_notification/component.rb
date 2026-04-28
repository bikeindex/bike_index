# frozen_string_literal: true

module Emails
  module ParkingNotification
    class Component < ApplicationComponent
      def initialize(parking_notification:, bike: nil, email_preview: false)
        @parking_notification = parking_notification
        @bike = bike
        @email_preview = email_preview
      end

      private

      def organization
        @parking_notification.organization
      end

      def bike
        @bike || @parking_notification.bike
      end

      def organization_snippet_body
        organization.mail_snippets.enabled.where(kind: @parking_notification.kind).first&.body
      end

      def impound_record
        return nil unless @parking_notification.impound_notification?

        @parking_notification.impound_record
      end

      def impound_location
        impound_record&.location
      end

      def show_pickup_link?
        return false if @parking_notification.other_parking_notification?
        return false if @parking_notification.impound_notification?

        tokenized_url.present?
      end

      def tokenized_url
        @email_preview ? OrganizedMailer::PREVIEW_TOKEN_URL : helpers.retrieval_link_url(@parking_notification)
      end

      def map_url
        latitude = @parking_notification.latitude
        longitude = @parking_notification.longitude
        "https://maps.googleapis.com/maps/api/staticmap?center=#{latitude},#{longitude}" \
          "&zoom=13&size=640x400&maptype=roadmap&scale=2" \
          "&markers=color:red%7C#{latitude},#{longitude}&key=#{ENV["GOOGLE_MAPS_STATIC"]}"
      end
    end
  end
end
