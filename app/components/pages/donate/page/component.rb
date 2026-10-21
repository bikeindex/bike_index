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
          x2d8tfop08gvzy7lsicfi2fwkzcg 6pbg4mj2fnhrw3pbvsyrm93t4n2z aq90e5l3o00eacqqnkw38k0fyk1h
          y1zx6uj63nr24sq13l40umjqu0iy okl6evn1b2rxevijirssjbtk4hvj 3x24hijp2tw39cn1potgkqo7hdtb
          wh198hgo27wt25cc83xhwzi4h439
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

          safe_join([number_display(count / 1_000_000), "M+"])
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
      end
    end
  end
end
