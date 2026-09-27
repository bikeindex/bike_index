# frozen_string_literal: true

module Pages
  module RecoveryStories
    module Index
      # "Load more" nests each page's frame inside the one before it, so a click swaps the
      # button's frame for the next page's stories - plus the frame for the page after
      class Component < ApplicationComponent
        PER_PAGE = 9
        REFERRAL_SOURCE = "recovery-stories"
        LINKED_CARD_CLASSES = "tw:hover:-translate-y-1.25 tw:hover:text-gray-700 tw:hover:shadow-[0_10px_30px_rgba(44,62,80,.18)]"

        def initialize(recovery_displays:, pagy:, total_bikes:, recoveries_count:, recoveries_value:,
          organizations_count:, currency:)
          @recovery_displays = recovery_displays
          @pagy = pagy
          @total_bikes = total_bikes
          @recoveries_count = recoveries_count
          @recoveries_value = recoveries_value
          @organizations_count = organizations_count
          @currency = currency
        end

        private

        def stats
          [{value: bikes_display, label: translation(".bikes_registered_free")},
            {value: number_display(@recoveries_count), label: translation(".stolen_bikes_recovered")},
            {value: render(Atoms::CurrencyMillions::Component.new(dollars_usd: @recoveries_value)),
             label: translation(".value_returned_to_owners")},
            {value: safe_join([number_display(@organizations_count), "+"]),
             label: translation(".partner_organizations")}]
        end

        def bikes_display
          return number_display(@total_bikes) if @total_bikes < 1_000_000

          safe_join([number_display(@total_bikes / 1_000_000), "M+"])
        end

        def membership_options
          [{value: "basic", cents: 499, note: translation(".basic_membership")},
            {value: "plus", cents: 999, note: translation(".plus_membership"), checked: true},
            {value: "patron", cents: 4999, note: translation(".patron_membership")}]
            .map { it.merge(amount: MoneyFormatter.money_format(it[:cents], @currency.slug)) }
            .map { it.merge(label: translation(".become_a_member", amount: it[:amount])) }
        end

        def donation_options
          [{value: 25, note: translation(".donation_search")},
            {value: 50, note: translation(".donation_alerts"), checked: true},
            {value: 100, note: translation(".donation_partners")}]
            .map { it.merge(amount: MoneyFormatter.money_format_without_cents(it[:value] * 100, @currency.slug)) }
            .map { it.merge(label: translation(".donate_amount", amount: it[:amount])) }
        end

        def gift_forms
          [{id: "gift_monthly", url: new_membership_path, name: :membership_level, options: membership_options,
            hidden: {referral_source: REFERRAL_SOURCE, currency: @currency.slug}, classes: "tw:flex tw:group-has-[#gift-cadence-one-time:checked]:hidden"},
            {id: "gift_one_time", url: donate_path, name: :initial_amount, options: donation_options,
             hidden: {source: REFERRAL_SOURCE}, classes: "tw:hidden tw:group-has-[#gift-cadence-one-time:checked]:flex"}]
        end

        def cadences
          [{id: "gift-cadence-monthly", label: translation(".monthly"), checked: true},
            {id: "gift-cadence-one-time", label: translation(".one_time")}]
        end

        def next_page_path = recovery_stories_path(page: @pagy.next, per_page: (@pagy.limit unless @pagy.limit == PER_PAGE))

        def container = "tw:mx-auto tw:max-w-300 tw:px-6"

        def h2_classes = "tw:m-0 tw:font-header tw:font-extrabold tw:tracking-tight tw:text-slate-900"
      end
    end
  end
end
