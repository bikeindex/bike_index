# frozen_string_literal: true

module Admin
  module CurrentHeader
    class ComponentPreview < ApplicationComponentPreview
      # @!group Header Variants

      def default
        render(Admin::CurrentHeader::Component.new(index: index_state, viewing: "Notifications"))
      end

      def with_current_organization
        current_organization = Organization.friendly_find "brakebills"
        primary_activity = PrimaryActivity.friendly_find "Gravel"
        render(Admin::CurrentHeader::Component.new(index: index_state(current_organization:, primary_activity:), viewing: "Notifications"))
      end

      def with_bike
        bike = Bike.first
        render(Admin::CurrentHeader::Component.new(index: index_state(params: {search_bike_id: bike.id}, bike:), viewing: "Activities"))
      end

      private

      def index_state(params: {}, **attrs)
        ComponentStructs::IndexState.new(params: ActionController::Parameters.new(params), **attrs)
      end
    end
  end
end
