# frozen_string_literal: true

module Pages
  module Memberships
    module New
      # The summary and join labels follow the checked tier and interval through
      # memberships--new, which reads them off each tier's radio. Prices swap on CSS alone
      class Component < ApplicationComponent
        # What the active StripePrices charge — the checkout looks the price up by level and interval
        PRICES = {basic: {monthly: 499, yearly: 4999}, plus: {monthly: 999, yearly: 9999},
                  patron: {monthly: 4999, yearly: 49_999}}.freeze

        MONTHLY_ONLY = "tw:group-has-[[value=yearly]:checked]/membership:hidden"
        YEARLY_ONLY = "tw:hidden tw:group-has-[[value=yearly]:checked]/membership:inline"

        def initialize(currency:, bikes_count:, recoveries_count:, recoveries_value:, organizations_count:,
          recovery_displays:, level: nil, referral_source: nil)
          @currency = currency
          @bikes_count = bikes_count
          @recoveries_count = recoveries_count
          @recoveries_value = recoveries_value
          @organizations_count = organizations_count
          @recovery_displays = recovery_displays.first(4)
          @referral_source = referral_source
          @membership = Membership.new(level: PRICES.key?(level&.to_sym) ? level.to_sym : :plus,
            set_interval: StripePrice.interval_default)
        end

        private

        def price(level, interval) = MoneyFormatter.money_format(PRICES[level][interval], @currency)

        def level_name(level) = Membership.level_humanized(level.to_s)

        def summary_label(level, interval)
          name = level_name(level)
          price = price(level, interval)
          (interval == :yearly) ? translation(".summary_yearly", level: name, price:) : translation(".summary_monthly", level: name, price:)
        end

        def join_label(level, interval)
          name = level_name(level)
          price = price(level, interval)
          (interval == :yearly) ? translation(".join_yearly", level: name, price:) : translation(".join_monthly", level: name, price:)
        end

        def interval_labels(level)
          %i[monthly yearly].index_with { {summary: summary_label(level, it), join: join_label(level, it)} }
        end

        def selected_level = @membership.level.to_sym

        def selected_interval = @membership.set_interval.to_sym

        def bikes_display
          return safe_join([number_display(@bikes_count), "+"]) if @bikes_count < 1_000_000

          safe_join([number_display(@bikes_count / 1_000_000), "M+"])
        end

        def stats
          [{value: bikes_display, label: translation(".bikes_registered_free")},
            {value: number_display(@recoveries_count), label: translation(".stolen_bikes_recovered")},
            {value: render(Atoms::CurrencyMillions::Component.new(dollars_usd: @recoveries_value)),
             label: translation(".value_returned_to_owners")},
            {value: safe_join([number_display(@organizations_count), "+"]),
             label: translation(".partner_organizations")}]
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

        def section_inner = "tw:mx-auto tw:max-w-6xl tw:px-5 tw:py-8 tw:lg:px-14 tw:lg:py-14"

        def eyebrow_classes = "tw:text-[11.5px] tw:font-extrabold tw:tracking-widest tw:uppercase"

        def h2_classes = "tw:m-0 tw:font-header tw:text-[26px] tw:font-extrabold tw:text-slate-900 tw:lg:text-[34px]"

        def h3_classes = "tw:m-0 tw:font-header tw:text-[24px] tw:leading-tight tw:font-extrabold tw:text-slate-900 tw:lg:text-[30px]"
      end
    end
  end
end
