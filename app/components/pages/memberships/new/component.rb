# frozen_string_literal: true

module Pages
  module Memberships
    module New
      # The summary and join labels follow the checked tier and interval through
      # memberships--new, which reads them off each tier's radio. Prices swap on CSS alone
      class Component < ApplicationComponent
        MONTHLY_ONLY = "tw:group-has-[[value=yearly]:checked]/membership:hidden"
        YEARLY_ONLY = "tw:hidden tw:group-has-[[value=yearly]:checked]/membership:inline"

        def initialize(stripe_prices:, bikes_count:, recoveries_count:, recoveries_value:, organizations_count:,
          recovery_displays:, level: nil, referral_source: nil, membership: nil)
          @currency = stripe_prices.first&.currency_obj || Currency.default
          @amounts = stripe_prices.to_h { [[it.membership_level.to_sym, it.interval.to_sym], it.amount_cents] }
          @bikes_count = bikes_count
          @recoveries_count = recoveries_count
          @recoveries_value = recoveries_value
          @organizations_count = organizations_count
          @recovery_displays = recovery_displays
          @referral_source = referral_source
          @membership = membership
          @level = Membership::LEVEL_ENUM.key?(level&.to_sym) ? level.to_sym : :plus
          @interval = StripePrice.interval_default.to_sym
        end

        private

        def price(level, interval)
          @amounts[[level, interval]]&.then { MoneyFormatter.money_format_no_cents_if_whole(it, @currency.slug) }
        end

        def level_name(level) = Membership.level_humanized(level.to_s)

        def labels(level, interval)
          args = {level: level_name(level), price: price(level, interval)}
          return {summary: translation(".summary_yearly", **args), join: translation(".join_yearly", **args)} if interval == :yearly

          {summary: translation(".summary_monthly", **args), join: translation(".join_monthly", **args)}
        end

        def interval_labels(level) = %i[monthly yearly].index_with { labels(level, it) }

        def bikes_millions
          number_with_precision(@bikes_count / 1_000_000.0, precision: 1, round_mode: :floor, strip_insignificant_zeros: true)
        end

        def bikes_display
          return safe_join([number_display(@bikes_count), "+"]) if @bikes_count < 1_000_000

          "#{bikes_millions}M+"
        end

        def members_keep_it_free
          if @bikes_count < 1_000_000
            return translation(".bikes_registered_keep_it_free", bikes: number_with_delimiter(@bikes_count))
          end

          translation(".millions_registered_keep_it_free", millions: bikes_millions)
        end

        def stats
          [[bikes_display, translation(".bikes_registered")],
            [number_display(@recoveries_count), translation(".stolen_bikes_recovered")],
            [render(Atoms::CurrencyMillions::Component.new(dollars_usd: @recoveries_value)), translation(".value_returned_to_owners")],
            [safe_join([number_display(@organizations_count), "+"]), translation(".partner_organizations")]]
        end

        def tiers
          [{level: :basic, perks: [translation(".perk_listings_promoted"), translation(".perk_member_badge"),
            translation(".perk_faster_support")]},
            {level: :plus, recommended: true,
             perks: [translation(".perk_everything_in_basic"), translation(".perk_promoted_alert"),
               translation(".perk_no_ads"), translation(".perk_cycling_cap")]},
            {level: :patron, perks: [translation(".perk_everything_in_basic_and_plus"),
              translation(".perk_top_listing_placement"), translation(".perk_patron_badge"),
              translation(".perk_sun_shirt")]}]
        end

        def interval_entries
          [{value: "monthly", label: translation(".monthly")}, {value: "yearly", label: translation(".yearly")}]
        end

        def keeps_free
          [{icon: "icons/searcher.svg", circle: "tw:bg-blue-600",
            title: translation(".free_registration_title"), body: translation(".free_registration_body")},
            {icon: "icons/megaphone.svg", circle: "tw:bg-red-600",
             title: translation(".free_alerts_title"), body: translation(".free_alerts_body")},
            {icon: "icons/handshake.svg", circle: "tw:bg-slate-900",
             title: translation(".free_partners_title"), body: translation(".free_partners_body")}]
        end

        def builds_next
          [{title: translation(".next_marketplace_title"), body: translation(".next_marketplace_body"), live: true},
            {title: translation(".next_ios_app_title"), body: translation(".next_ios_app_body"), live: true},
            {title: translation(".next_oem_parts_title"), body: translation(".next_oem_parts_body")},
            {title: translation(".next_versioning_title"), body: translation(".next_versioning_body")},
            {title: translation(".next_ebike_database_title"), body: translation(".next_ebike_database_body")}]
        end

        def partner_logos
          {"SFPD.png" => "San Francisco Police Department", "University-of-Washington.png" => "University of Washington",
           "City-of-Bend.png" => "City of Bend", "Joe-Bike.png" => "Joe Bike",
           "Santa-Monica-PD.png" => "Santa Monica Police Department", "UMD.png" => "University of Maryland"}
        end

        def gear
          [{name: translation(".cycling_cap"), level: :plus,
            src: "https://files.bikeindex.org/uploads/Pu/1020927/cycling-cap.png"},
            {name: translation(".sun_shirt"), level: :patron,
             src: "https://files.bikeindex.org/uploads/Pu/1020925/thuja-sun-hoodie.jpg"}]
        end

        def faqs
          [[translation(".faq_free_question"), translation(".faq_free_answer")],
            [translation(".faq_tax_question"), translation(".faq_tax_answer")],
            [translation(".faq_cancel_question"), translation(".faq_cancel_answer")],
            [translation(".faq_marketplace_question"), translation(".faq_marketplace_answer")],
            [translation(".faq_gear_question"), translation(".faq_gear_answer")]]
        end

        def section_inner = "#{SharedBlocks::Marketing::Wrapper::Component::CONTAINER_CLASSES} tw:py-8 tw:lg:py-14"
      end
    end
  end
end
