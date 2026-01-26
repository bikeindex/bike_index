# frozen_string_literal: true

module Admin::UserShow
  class Component < ApplicationComponent
    def initialize(user:, bikes:, bikes_count:)
      @user = user
    @bikes = bikes
    @bikes_count = bikes_count
    end
  end
end
