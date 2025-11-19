# frozen_string_literal: true

module Admin::CurrentHeader
  class ComponentPreview < ApplicationComponentPreview
    # @group Header Variants

    def default
      render(Admin::CurrentHeader::Component.new(params: {}))
    end

    def with_user
      user = User.first
      render(Admin::CurrentHeader::Component.new(params: passed_params(user_id: user.id), user:, viewing: "Notifications"))
    end

    def with_bike
      bike = Bike.first
      render(Admin::CurrentHeader::Component.new(params: passed_params(search_bike_id: bike.id), bike:, viewing: "Activities"))
    end

    private

    def passed_params(hash)
      ActionController::Parameters.new(hash)
    end
  end
end
