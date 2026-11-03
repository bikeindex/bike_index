# frozen_string_literal: true

module Pages
  module Donate
    module Page
      # The major gift cards and the closing CTA sit outside Pages::Donate::Form, so the
      # donate--page controller reaches its donate--form controller through window events
      class Component < ApplicationComponent
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
          @form = Pages::Donate::Form::Component.new(stripe_prices:, initial_amount:, referral_source:, current_user:)
          @recovery_displays = recovery_displays
          @referral_source = referral_source
        end

        private

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

          "#{number_with_precision(count / 1_000_000.0, precision: 1, round_mode: :floor, strip_insignificant_zeros: true)}M+"
        end

        def major_gifts
          MAJOR_AMOUNTS.zip([translation(".major_partner"), translation(".major_benefactor")])
        end

        def money_uses
          [{icon: "icons/lucide-search.svg", circle: "tw:bg-blue-600",
            title: translation(".uses_free_title"), body: translation(".uses_free_body")},
            {icon: "icons/lucide-megaphone.svg", circle: "tw:bg-purple-500",
             title: translation(".uses_alerts_title"), body: translation(".uses_alerts_body")},
            {icon: "icons/lucide-handshake.svg", circle: "tw:bg-slate-900",
             title: translation(".uses_partners_title"), body: translation(".uses_partners_body")},
            {icon: "icons/lucide-store.svg", circle: "tw:bg-blue-500",
             title: translation(".uses_owners_title"), body: translation(".uses_owners_body")}]
        end
      end
    end
  end
end
