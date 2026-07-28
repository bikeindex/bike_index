# frozen_string_literal: true

module Admin
  module BikeCreationData
    # The ownership and BParam dump below the admin bike edit form (Admin::BikeEdit).
    # It's expanded from the start when display_dev_info?
    class Component < ApplicationComponent
      OWNERSHIP_SKIPPED_ATTRIBUTES = %w[creator_id bike_id organization_id created_at updated_at token id].freeze

      def initialize(bike:)
        @bike = bike
      end

      private

      def ownerships
        @bike.ownerships.includes(:creator).reorder(created_at: :desc)
      end

      def b_params
        @b_params ||= @bike.b_params.to_a
      end
    end
  end
end
