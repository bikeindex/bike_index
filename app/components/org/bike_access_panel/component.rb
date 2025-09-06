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
        @user.authorized?(@organization) && @bike.visible_by?(@user)
    end

    private

    def phone_display(str)
      return "" if str.blank?
      phone_components = Phonifyer.components(str)
      number_to_phone(phone_components[:number], phone_components.except(:number))
    end

    def phone_link(phone, html_options = {})
      return "" if phone.blank?
      phone_d = phone_display(phone)
      # Switch extension to be pause in link
      link_to(phone_d, "tel:#{phone_d.tr("x", ";")}", html_options)
    end

    def organization_registered?
      return @organization_registered if defined?(@organization_registered)

      @organization_registered = @bike.organized?(@organization)
    end

    def organization_authorized?
      @bike.authorized_by_organization?(org: @organization)
    end

    def user_can_edit?
      @bike.authorized?(@user)
    end

    # Only show the unstolen notification form if bike is with_owner (ie, not if bike is found)
    def display_unstolen_notification_form?
      @bike.status_with_owner? && @organization.enabled?("unstolen_notifications")
    end

    def show_sticker_modal?
      # display stickers if org has paid for them
      @organization.enabled?("bike_stickers")
    end

    def display_original_ownership?
      original_ownership.id != @bike.current_ownership_id &&
        original_ownership.organization_id == @organization.id
    end

    def current_ownership
      @current_ownership ||= @bike.current_ownership
    end

    def original_ownership
      @original_ownership ||= @bike.ownerships.initial.first
    end
  end
end
