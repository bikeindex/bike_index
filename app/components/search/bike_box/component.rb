# frozen_string_literal: true

module Search::BikeBox
  class Component < ApplicationComponent
    include BikeHelper

    # NOTE: be cautious about passing in current_user and caching,
    # since current_user shows their hidden serials
    def initialize(bike:, current_user: nil)
      @bike = bike
      @current_user = current_user
    end
  end
end
