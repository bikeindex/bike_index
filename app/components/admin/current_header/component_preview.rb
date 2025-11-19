# frozen_string_literal: true

module Admin::CurrentHeader
  class ComponentPreview < ApplicationComponentPreview
    # @group Header Variants

    def default
      render(Admin::CurrentHeader::Component.new(params: {}))
    end

    def with_user
      user = User.first || FactoryBot.create(:user)
      render(Admin::CurrentHeader::Component.new(params: {user_id: user.id}, user:, viewing: "Notifications"))
    end

    def with_bike
      bike = Bike.first || FactoryBot.create(:bike)
      render(Admin::CurrentHeader::Component.new(params: {search_bike_id: bike.id}, bike:, viewing: "Activities"))
    end
  end
end
