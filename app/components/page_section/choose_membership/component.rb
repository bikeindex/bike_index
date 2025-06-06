# frozen_string_literal: true

module PageSection::ChooseMembership
  class Component < ApplicationComponent
    def initialize(currency:, interval: nil, level: nil, membership: nil, referral_source: nil)
      @currency = currency
      @membership = membership || Membership.new
      @membership.set_interval = @membership.interval || interval || StripePrice.interval_default
      @membership.level ||= passed_membership_level(level)
      @referral_source = referral_source
    end

    private

    def price_display(amount_cents, interval)
      interval_display = (interval == "monthly") ? "month" : "year"
      interval_classes = "intervalDisplay #{interval} #{(@membership.set_interval == interval) ? "" : "tw:hidden!"}"

      tag.h3(class: "tw:inline-flex tw:items-stretch #{interval_classes}") do
        safe_join([
          tag.span(MoneyFormatter.money_format(amount_cents, @currency), class: "tw:text-2xl tw:font-semibold"),
          tag.span(class: "tw:ml-1 tw:text-xs tw:flex tw:flex-col tw:justify-center tw:leading-none tw:text-left") do
            safe_join([
              tag.span("per"),
              tag.span(interval_display)
            ])
          end
        ])
      end
    end

    def passed_membership_level(level = nil)
      return :basic unless Membership::LEVEL_ENUM.keys.include?(level&.to_sym)

      level.to_sym
    end

    # TODO: Actually use membership levels
    def membership_levels
      Membership.levels_ordered
    end
  end
end
