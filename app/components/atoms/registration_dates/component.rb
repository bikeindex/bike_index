# frozen_string_literal: true

module Atoms
  module RegistrationDates
    # A bike's registered and updated dates. Below 24rem the labels shrink to a letter,
    # spelled out in a tooltip - so the row rendering it has to be a tw:@container
    class Component < ApplicationComponent
      def initialize(bike:)
        @bike = bike
      end
    end
  end
end
