# frozen_string_literal: true

module Registrations
  module ShowPage
    # Entry point for the bike show page: renders the redesigned admin or
    # consumer view when eligible, otherwise the legacy page
    class Component < ApplicationComponent
      # The redesign only covers the common "registered, not stolen" case -
      # stolen/impounded/found bikes and versions keep the legacy page
      def self.redesign?(bike, user)
        Flipper.enabled?(:bike_show_redesign, user) && bike.status_with_owner? && !bike.version?
      end

      # Org staff viewing an accessible bike get the redesigned admin panel in
      # place of the legacy Org::BikeAccessPanel
      def self.admin_redesign?(bike, user, organization)
        return false unless redesign?(bike, user)

        organization.present? && user&.authorized?(organization) && bike.visible_by?(user)
      end

      def initialize(bike:, current_user:, organization: nil, show_for_sale: false)
        @bike = bike
        @current_user = current_user
        @organization = organization
        @show_for_sale = show_for_sale
      end

      def call
        if admin_redesign?
          render(BikeAdminRedesign::Component.new(bike: @bike, current_user: @current_user, organization: @organization))
        elsif redesign?
          render(BikeShowRedesign::Component.new(bike: @bike, current_user: @current_user, show_for_sale: @show_for_sale))
        else
          helpers.render(partial: "bikes/legacy_show")
        end
      end

      private

      def redesign?
        self.class.redesign?(@bike, @current_user)
      end

      def admin_redesign?
        self.class.admin_redesign?(@bike, @current_user, @organization)
      end
    end
  end
end
