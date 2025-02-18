# frozen_string_literal: true

module ChooseMembership
  class Component < ApplicationComponent
    def initialize(currency:, interval: nil, kind: nil, membership: nil)
      @currency = currency
      @membership = membership || Membership.new
      @interval ||= @membership.interval || interval || StripePrice.interval_default
      @membership.kind ||= kind
    end

    private

    def kind_li_classes
      "tw-inline-flex tw-items-center tw-justify-between tw-shadow-sm tw-rounded tw-text-center tw-border tw-border-gray-200 dark:tw-border-gray-700 hover:tw-bg-gray-100 dark:hover:tw-bg-gray-800 focus-visible:tw-outline focus-visible:tw-outline-2 focus-visible:tw-outline-offset-2 focus-visible:tw-outline-gray-800"
    end

    def membership_kinds
      Membership.kinds_ordered
    end
  end
end
