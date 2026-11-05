# frozen_string_literal: true

module Pages
  module MyAccount
    module Memberships
      module Show
        # Members keep the price they signed up at, so compare it with the active StripePrice a
        # new member checks out with
        class Component < ApplicationComponent
          def initialize(membership:)
            @membership = membership
            @stripe_price = membership.current_stripe_subscription&.stripe_price if membership&.stripe_managed?
            @current_price = @stripe_price &&
              StripePrice.active.find_by(@stripe_price.slice(:membership_level, :interval, :currency_enum))
          end

          private

          def level = @membership.level_humanized

          def price_display(stripe_price)
            amount = MoneyFormatter.money_format_no_cents_if_whole(stripe_price.amount_cents, stripe_price.currency_enum)
            "#{amount} #{stripe_price.yearly? ? translation(".per_year") : translation(".per_month")}"
          end

          def price_comparison
            args = {level:, current_price: price_display(@current_price)}
            case @stripe_price.amount_cents <=> @current_price.amount_cents
            when -1 then translation(".you_pay_less", **args)
            when 0 then translation(".you_pay_the_current_price", **args)
            else translation(".new_members_pay", **args)
            end
          end
        end
      end
    end
  end
end
