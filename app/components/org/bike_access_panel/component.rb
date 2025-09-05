# frozen_string_literal: true

module Org::BikeAccessPanel
  class Component < ApplicationComponent
    include OrganizedHelper

    def initialize(bike: nil, organization: nil, current_user: nil)
      @bike = bike
      @organization = organization
      @user = current_user
    end

    def render?
      @bike.present? && @organization.present? && @user.present? &&
        @user.authorized?(@organization)
    end

    private

    def organization_registered?
      @bike.organized?(@organization)
    end

    def organization_authorized?
      @bike.authorized_by_organization?(org: @organization)
    end

    # Only show the unstolen notification form if bike is with_owner (ie, not if bike is found)
    def display_unstolen_notification_form?
      @bike.status_with_owner? && @organization.enabled?("unstolen_notifications")
    end

    def show_sticker_modal?
      # display stickers if org has paid for them
      @organization.enabled?("bike_stickers")
    end
  end
end
