# frozen_string_literal: true

module Pages
  module Register
    module Parts
      module LandingDonation
        # The landing page's donation ask: a form per cadence, submitting to the membership
        # page or the donate page. register--landing-donation puts the pick's amount on the
        # buttons and takes a custom one-time amount
        class Component < ApplicationComponent
          # Ahead of Pages::Memberships::ChooseMembership, which still shows the old Stripe prices
          MEMBERSHIP_CENTS = {basic: 500, plus: 1500, patron: 5000}.freeze

          ONE_TIME_DOLLARS = [25, 50, 100].freeze

          RADIO_CLASSES = "tw:mt-1 tw:size-5 tw:shrink-0 tw:accent-blue-600"

          CTA_ROW_CLASSES = "tw:flex tw:flex-wrap tw:items-center tw:gap-x-5 tw:gap-y-3"

          CTA_CLASSES = "tw:w-full tw:px-4! tw:text-sm! tw:sm:w-auto tw:sm:px-8! tw:sm:text-base!"

          FINE_PRINT_CLASSES = "tw:m-0 tw:flex-1 tw:basis-60 tw:text-[13px]"

          private

          def membership_tiles
            @membership_tiles ||= MEMBERSHIP_CENTS.map do |level, cents|
              price = MoneyFormatter.money_format_without_cents(cents)
              {amount: price, name: translation(".membership_level", level: Membership.level_humanized(level.to_s)),
               value: level, checked: level == :plus, label: translation(".become_a_member", amount: price)}
            end
          end

          def one_time_tiles
            ONE_TIME_DOLLARS.map do |dollars|
              amount = MoneyFormatter.money_format_without_cents(dollars * 100)
              {amount:, value: dollars, checked: dollars == 50, label: translation(".donate", amount:)}
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
end
