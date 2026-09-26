# frozen_string_literal: true

module Pages
  module Register
    module LandingDonation
      # The landing page's donation ask. Monthly tiles start a membership and one-time ones
      # the donate page - register--landing-donation points the call to action at the pick
      class Component < ApplicationComponent
        # Ahead of Pages::Memberships::ChooseMembership, which still shows the old Stripe prices
        MEMBERSHIP_CENTS = {basic: 500, plus: 1500, patron: 5000}.freeze

        ONE_TIME_DOLLARS = [25, 50, 100].freeze

        RADIO_CLASSES = "tw:mt-1 tw:size-5 tw:shrink-0 tw:accent-blue-600"

        private

        def membership_tiles
          @membership_tiles ||= MEMBERSHIP_CENTS.map do |level, cents|
            price = MoneyFormatter.money_format_without_cents(cents)
            {amount: price, name: translation(".membership_level", level: Membership.level_humanized(level.to_s)),
             checked: level == :plus, href: new_membership_path(membership_level: level),
             label: translation(".become_a_member", amount: price)}
          end
        end

        # What the call to action points at before the controller connects
        def default_tile = membership_tiles.detect { it[:checked] }

        def one_time_tiles
          ONE_TIME_DOLLARS.map do |dollars|
            amount = MoneyFormatter.money_format_without_cents(dollars * 100)
            {amount:, checked: dollars == 50, href: donate_path(initial_amount: dollars),
             label: translation(".donate", amount:)}
          end
        end

        def tile_classes
          "tw:flex tw:cursor-pointer tw:items-center tw:sm:items-start tw:justify-between tw:gap-2 tw:rounded-lg tw:border " \
            "tw:border-gray-200 tw:bg-white tw:px-4 tw:py-3 tw:sm:py-4 tw:transition-colors tw:duration-150 tw:hover:border-blue-300 " \
            "tw:has-checked:border-blue-600 tw:has-checked:ring-1 tw:has-checked:ring-blue-600 " \
            "tw:has-focus-visible:outline-2 tw:has-focus-visible:outline-offset-2 tw:has-focus-visible:outline-blue-500"
        end

        def cadence_classes
          "tw:mb-0 tw:cursor-pointer tw:border-b-3 tw:border-transparent tw:px-4 tw:pb-2 tw:text-sm tw:font-semibold " \
            "tw:tracking-wide tw:text-gray-500 tw:uppercase tw:has-checked:border-blue-500 tw:has-checked:text-blue-500 " \
            "tw:has-focus-visible:outline-2 tw:has-focus-visible:outline-blue-500"
        end
      end
    end
  end
end
