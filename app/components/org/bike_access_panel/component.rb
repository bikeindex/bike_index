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
  end
end
