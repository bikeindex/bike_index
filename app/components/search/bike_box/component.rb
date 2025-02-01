# frozen_string_literal: true

module Search::BikeBox
  class Component < ApplicationComponent
    def initialize(bike:, current_user:)
      @bike = bike
      @current_user = current_user
    end
  end
end
