# frozen_string_literal: true

module Pages
  module Donate
    module Page
      # Monthly gifts check out as a membership subscription, one-time gifts as a donation
      # payment. The cadence radios switch between the two forms in CSS, so both submit
      # without javascript - the donate--page controller only keeps the labels in step.
      class Component < ApplicationComponent
        ONE_TIME_AMOUNTS = [25, 50, 100].freeze
        MAJOR_AMOUNTS = [500, 1000].freeze

        # Hand-picked recovery story photos that show the whole bike - the newest story
        # photos are as often a serial sticker or a selfie
        WALL_PHOTOS = %w[
          zifmz9ievoovtx971osxccoexyw3 yato0hk1laa4us6otl49uyzldoqu aq90e5l3o00eacqqnkw38k0fyk1h
          gfpgif7uxjy2y7rh11n36uzbfxdd owvsv1dvbn2ljtwglyebih6vwyce xfgqrcjh7ejblp6cffy77a85gotg
          eslpqitkldruibfba8uwt8j0x63v
        ].map { "https://uploads.bikeindex.org/#{it}" }.freeze

        def initialize(stripe_prices:, recovery_displays:, initial_amount: nil, referral_source: nil,
          current_user: nil)
          @currency = stripe_prices.first&.currency_obj || Currency.default
          @monthly_prices = stripe_prices.select(&:monthly?).to_h do
            [it.membership_level.to_sym, MoneyFormatter.money_format_no_cents_if_whole(it.amount_cents, @currency.slug)]
          end
          @recovery_displays = recovery_displays
          @initial_amount = initial_amount.to_i if initial_amount.to_i.positive?
          @referral_source = referral_source
          @email = current_user&.email
          @member = current_user&.membership_active.present?
        end

        private

        def monthly? = !@member

        def one_time? = !monthly? || @initial_amount.present?

        def custom_amount
          @initial_amount unless ONE_TIME_AMOUNTS.include?(@initial_amount)
        end

        def selected_one_time = @initial_amount || 50

        def money(dollars)
          return MoneyFormatter.money_format_without_cents(dollars * 100, @currency) if dollars % 1 == 0

          MoneyFormatter.money_format(dollars * 100, @currency)
        end

        def tier_amount(level) = @monthly_prices[level]

        def monthly_label(amount) = translation(".monthly_submit", amount:)

        def one_time_label(amount) = translation(".one_time_submit", amount:)

        def one_time_submit = one_time_label(money(selected_one_time))

        def monthly_submit = monthly_label(tier_amount(:plus))

        def submit_label = one_time? ? one_time_submit : monthly_submit

        def stats
          [
            [abbreviated(Counts.total_bikes), translation(".stat_bikes")],
            [number_display(Counts.recoveries), translation(".stat_recoveries")],
            [render(Atoms::CurrencyMillions::Component.new(dollars_usd: Counts.recoveries_value)),
              translation(".stat_value")],
            [safe_join([number_display(Counts.organizations.floor(-2)), "+"]), translation(".stat_partners")]
          ]
        end

        def abbreviated(count)
          return number_display(count) if count < 1_000_000

          safe_join([number_display(count / 1_000_000), "M+"])
        end

        def tiers
          [
            [:basic, translation(".tier_basic"), translation(".tier_basic_benefit")],
            [:plus, translation(".tier_plus"), translation(".tier_plus_benefit")],
            [:patron, translation(".tier_patron"), translation(".tier_patron_benefit")]
          ]
        end

        def major_gifts
          MAJOR_AMOUNTS.zip([translation(".major_partner"), translation(".major_benefactor")])
        end

        def money_uses
          [
            ["lucide-search", "tw:bg-blue-600", translation(".uses_free_title"), translation(".uses_free_body")],
            ["lucide-megaphone", "tw:bg-purple-500", translation(".uses_alerts_title"), translation(".uses_alerts_body")],
            ["lucide-handshake", "tw:bg-[#2c3e50]", translation(".uses_partners_title"), translation(".uses_partners_body")],
            ["lucide-store", "tw:bg-blue-500", translation(".uses_owners_title"), translation(".uses_owners_body")]
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
