# frozen_string_literal: true

module ChooseMembership
  class Component < ApplicationComponent
    def initialize(currency:, interval: nil, kind: nil, membership: nil)
      @currency = currency
      @membership = membership || Membership.new
      @interval ||= @membership.interval || interval || StripePrice.interval_default
      @membership.kind ||= kind || :basic
    end

    private

    def price_display(amount_cents, interval)
      tag.h3(class: "tw:inline-flex tw:items-stretch") do
        safe_join([
          tag.span(MoneyFormatter.money_format(amount_cents, @currency), class: "tw:text-2xl tw:font-semibold"),
          tag.span(class: "tw:ml-1 tw:text-xs tw:flex tw:flex-col tw:justify-center tw:leading-none tw:text-left") do
            safe_join([
              tag.span("per"),
              tag.span(interval)
            ])
          end
        ])
      end
    end


    def membership_kinds
      Membership.kinds_ordered
    end
  end
end
