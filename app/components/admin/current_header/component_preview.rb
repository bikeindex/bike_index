# frozen_string_literal: true

module Admin::CurrentHeader
  class ComponentPreview < ApplicationComponentPreview
    # @group Header Variants

    def default
      render(Admin::CurrentHeader::Component.new(params: passed_params))
    end

    def with_current_organization
      current_organization = Organization.friendly_find "hogwarts"
      primary_activity = PrimaryActivity.friendly_find "Gravel"
      render(Admin::CurrentHeader::Component.new(current_organization:, params: passed_params, primary_activity:, viewing: "Notifications"))
    end

    def with_bike
      bike = Bike.first
      render(Admin::CurrentHeader::Component.new(params: passed_params(search_bike_id: bike.id), bike:, viewing: "Activities"))
    end

    private

    def passed_params(hash = {})
      ActionController::Parameters.new(hash)
    end
  end
end
