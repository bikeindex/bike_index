# frozen_string_literal: true

module Pages
  module Donate
    module Page
      # Monthly gifts check out as a membership subscription, one-time gifts as a donation
      # payment. The cadence radios switch between the two forms in CSS, so both submit
      # without javascript - the donate--page controller only keeps the labels in step.
      class Component < ApplicationComponent
        # The monthly StripePrices; Pages::Memberships::ChooseMembership shows the same
        MONTHLY_TIERS = {basic: 499, plus: 999, patron: 4999}.freeze
        ONE_TIME_AMOUNTS = [25, 50, 100].freeze
        MAJOR_AMOUNTS = [500, 1000].freeze

        # Hand-picked recovery story photos that show the whole bike - the newest story
        # photos are as often a serial sticker or a selfie
        WALL_PHOTOS = %w[
          x2d8tfop08gvzy7lsicfi2fwkzcg 6pbg4mj2fnhrw3pbvsyrm93t4n2z aq90e5l3o00eacqqnkw38k0fyk1h
          y1zx6uj63nr24sq13l40umjqu0iy okl6evn1b2rxevijirssjbtk4hvj 3x24hijp2tw39cn1potgkqo7hdtb
          wh198hgo27wt25cc83xhwzi4h439
        ].map { "https://uploads.bikeindex.org/#{it}" }.freeze

        def initialize(recovery_displays:, currency: Currency.default, initial_amount: nil, referral_source: nil,
          current_user: nil)
          @recovery_displays = recovery_displays.select { it.photo_url.present? }.first(4)
          @currency = currency
          @initial_amount = initial_amount.to_i if initial_amount.to_i.positive?
          @referral_source = referral_source
          @current_user = current_user
          @member = current_user&.membership_active.present?
        end

        private

        def one_time? = @member || @initial_amount.present?

        def custom_amount
          @initial_amount unless ONE_TIME_AMOUNTS.include?(@initial_amount)
        end

        def selected_one_time = @initial_amount || 50

        def money(cents) = MoneyFormatter.money_format_without_cents(cents, @currency)

        def tier_amount(level) = MoneyFormatter.money_format(MONTHLY_TIERS[level], @currency)

        def monthly_label(amount) = translation(".monthly_submit", amount:)

        def one_time_label(amount) = translation(".one_time_submit", amount:)

        def submit_label
          return one_time_label(money(selected_one_time * 100)) if one_time?

          monthly_label(tier_amount(:plus))
        end

        def stats
          [
            [abbreviated(Counts.total_bikes), translation(".stat_bikes")],
            [number_display(Counts.recoveries), translation(".stat_recoveries")],
            [safe_join([@currency.symbol, number_display((Counts.recoveries_value / 1_000_000.0).round(1)), "M"]),
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

        def row_classes
          "tw:group/row tw:flex tw:cursor-pointer tw:items-center tw:gap-4 tw:rounded-lg tw:border " \
            "tw:border-gray-200 tw:bg-white tw:px-4.5 tw:py-4 tw:transition-colors tw:hover:border-[#a9d2f0] " \
            "tw:has-focus-visible:ring-3 tw:has-focus-visible:ring-blue-500/40 tw:is-active:border-blue-600 " \
            "tw:is-active:ring-1 tw:is-active:ring-blue-600 tw:is-active:hover:border-blue-600 " \
            "tw:dark:border-gray-700 tw:dark:bg-gray-800"
        end

        def radio_mark
          tag.span(class: "tw:ml-auto tw:flex tw:size-6 tw:shrink-0 tw:items-center tw:justify-center " \
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
