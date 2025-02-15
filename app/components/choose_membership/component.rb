# frozen_string_literal: true

module ChooseMembership
  class Component < ApplicationComponent
    def initialize(currency:)
      @currency = currency
    end

    private

    def membership_kinds
      Membership.kinds_ordered
    end
  end
end
