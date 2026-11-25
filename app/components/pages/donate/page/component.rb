# frozen_string_literal: true

module Pages
  module Donate
    module Page
      # The major gift cards and the closing CTA sit outside Pages::Donate::Form, so the
      # donate--page controller reaches its donate--form controller through window events
      class Component < ApplicationComponent
        def initialize(stripe_prices:, recovery_displays:, initial_amount: nil, referral_source: nil,
          current_user: nil)
          @form = Pages::Donate::Form::Component.new(stripe_prices:, initial_amount:, referral_source:, current_user:)
          @recovery_displays = recovery_displays
          @referral_source = referral_source
        end

        private

        def bikes_millions = @bikes_millions ||= Counts.in_millions(Counts.total_bikes)

        def money_uses
          [{icon: "icons/lucide-search.svg", circle: "tw:bg-blue-600",
            title: translation(".uses_free_title"), body: translation(".uses_free_body")},
            {icon: "icons/lucide-megaphone.svg", circle: "tw:bg-purple-500",
             title: translation(".uses_alerts_title"), body: translation(".uses_alerts_body")},
            {icon: "icons/lucide-handshake.svg", circle: "tw:bg-slate-900 tw:dark:bg-slate-600",
             title: translation(".uses_partners_title"), body: translation(".uses_partners_body")},
            {icon: "icons/lucide-store.svg", circle: "tw:bg-blue-500",
             title: translation(".uses_owners_title"), body: translation(".uses_owners_body")}]
        end
      end
    end
  end
end
