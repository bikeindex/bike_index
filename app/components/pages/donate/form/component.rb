# frozen_string_literal: true

module Pages
  module Donate
    module Form
      # Monthly gifts check out as a membership subscription, one-time gifts as a donation
      # payment. The cadence radios switch between the two forms in CSS, so both submit
      # without javascript - the donate--form controller only keeps the labels in step.
      class Component < ApplicationComponent
        ONE_TIME_AMOUNTS = [25, 50, 100].freeze
        MAX_AMOUNT = Payment::MAX_AMOUNT_CENTS / 100.0

        # amounts: the one-time presets, the middle one selected without an initial_amount
        # default_cadence: :monthly or :one_time, whichever tab leads and is selected first
        # one_time_intro: above the one-time form, outside it - so Enter in an input there doesn't submit a donation
        renders_one :one_time_intro, ->(component) { component }

        def initialize(stripe_prices:, initial_amount: nil, referral_source: nil, current_user: nil,
          amounts: ONE_TIME_AMOUNTS, default_cadence: :monthly)
          @currency = stripe_prices.first&.currency_obj || Currency.default
          @monthly_prices = stripe_prices.select(&:monthly?).to_h do
            [it.membership_level.to_sym, MoneyFormatter.money_format_no_cents_if_whole(it.amount_cents, @currency.slug)]
          end
          @initial_amount = initial_amount.to_i if initial_amount.to_i.between?(1, MAX_AMOUNT)
          @referral_source = referral_source
          @amounts = amounts
          @default_cadence = default_cadence
          @email = current_user&.email
          @member = current_user&.membership_active.present?
        end

        def custom_amount
          @initial_amount unless @amounts.include?(@initial_amount)
        end

        def currency_symbol = @currency.symbol

        # for a link back to the page, which takes its currency from the params
        def currency_param = (@currency.slug unless @currency.slug == Currency.default.slug)

        def submit_label = one_time? ? one_time_submit : monthly_submit

        def money(dollars)
          return MoneyFormatter.money_format_without_cents(dollars * 100, @currency) if dollars % 1 == 0

          MoneyFormatter.money_format(dollars * 100, @currency)
        end

        private

        def monthly? = !@member

        def one_time? = !monthly? || @initial_amount.present? || @default_cadence == :one_time

        def default_amount = @amounts[@amounts.size / 2]

        def selected_one_time = @initial_amount || default_amount

        def tier_amount(level) = @monthly_prices[level]

        def monthly_label(amount) = translation(".monthly_submit", amount:)

        def one_time_label(amount) = translation(".one_time_submit", amount:)

        def one_time_submit = one_time_label(money(selected_one_time))

        def monthly_submit = monthly_label(tier_amount(:plus))

        def cadences
          [["monthly", translation(".monthly")], ["one-time", translation(".one_time")]].then { (@default_cadence == :one_time) ? it.reverse : it }
        end

        def tiers
          [
            [:basic, translation(".tier_basic"), translation(".tier_basic_benefit")],
            [:plus, translation(".tier_plus"), translation(".tier_plus_benefit")],
            [:patron, translation(".tier_patron"), translation(".tier_patron_benefit")]
          ]
        end

        def radio_mark
          @radio_mark ||= tag.span(class: "tw:ml-auto tw:flex tw:size-6 tw:shrink-0 tw:items-center tw:justify-center " \
            "tw:rounded-full tw:border-[1.5px] tw:border-gray-300 tw:text-transparent " \
            "tw:group-has-checked/row:border-blue-600 tw:group-has-checked/row:bg-blue-600 " \
            "tw:group-has-checked/row:text-white") do
            helpers.inline_svg_tag("icons/check.svg", class: "tw:size-3.5", aria_hidden: true)
          end
        end
      end
    end
  end
end
