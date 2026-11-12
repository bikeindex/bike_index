# frozen_string_literal: true

module Pages
  module Donate
    module YearEnd
      # The page the year-end appeal emails link to. The form is Pages::Donate::Form with this campaign's
      # presets; its source - the email's own, so each is told apart - names the audience. A source containing
      # "recovered" gets the recovered-bike headline and the 10% helper open.
      class Component < ApplicationComponent
        # USD, like the stats beside it, whatever currency the form is in
        GOAL = 20_000
        RECOVERED = 1_358
        REGISTERED = 96_328
        REFERRAL_SOURCE = "eoy-2026"
        MARKETPLACE_FRAME_CLASS = "tw:[--frame-crop-x:0px] tw:[--frame-crop-top:700px] tw:[--frame-scale:0.4]"

        def initialize(stripe_prices:, initial_amount: nil, referral_source: nil, current_user: nil)
          # a source[]= param arrives as an Array
          @referral_source = (referral_source if referral_source.is_a?(String)).presence || REFERRAL_SOURCE
          @recovered = @referral_source.match?(/recovered/i)
          @form = Pages::Donate::Form::Component.new(stripe_prices:, initial_amount:, current_user:, referral_source: @referral_source,
            amounts: [50, 100, 250], default_cadence: :one_time)
        end

        private

        def photos = Pages::Donate::Page::Component::WALL_PHOTOS

        def goal = MoneyFormatter.money_format_without_cents(GOAL * 100, Currency.default)

        def stats
          [[number_display(RECOVERED), translation(".stat_recovered")],
            [translation(".stat_value_figure"), translation(".stat_value")],
            [number_display(REGISTERED), translation(".stat_registered")]]
        end

        def stories
          [[translation(".story_shop_title"), translation(".story_shop")],
            [translation(".story_country_title"), translation(".story_country")],
            [translation(".story_magic_title"), translation(".story_magic")]]
        end

        def shipped
          [{icon: "icons/clipboard.svg", circle: "tw:bg-blue-600", title: translation(".shipped_registration_title"), body: translation(".shipped_registration")},
            {icon: "icons/bolt.svg", circle: "tw:bg-purple-500", title: translation(".shipped_ebike_title"), body: translation(".shipped_ebike")},
            {icon: "icons/map-pin.svg", circle: "tw:bg-slate-900 tw:dark:bg-slate-600", title: translation(".shipped_legality_title"), body: translation(".shipped_legality")},
            {icon: "icons/chat.svg", circle: "tw:bg-blue-500", title: translation(".shipped_messaging_title"), body: translation(".shipped_messaging")},
            {icon: "icons/lucide-layout-dashboard.svg", circle: "tw:bg-blue-600", title: translation(".shipped_dashboard_title"), body: translation(".shipped_dashboard")},
            {icon: "icons/lucide-handshake.svg", circle: "tw:bg-purple-500", title: translation(".shipped_partners_title"), body: translation(".shipped_partners")}]
        end

        def building
          [{href: bikebook_path, icon: "icons/book-open.svg", circle: "tw:bg-purple-500",
            frame: bikebook_path(vehicle_models: Pages::LandingPages::ForBikeShops::Component::BIKE_BOOK_MODELS.join(",")),
            frame_class: Pages::LandingPages::ForBikeShops::Component::BIKE_BOOK_FRAME_CLASS,
            eyebrow: translation(".bikebook_eyebrow"), title: translation(".bikebook_title"),
            body: translation(".bikebook_body"), action: translation(".bikebook_link")},
            {href: search_marketplace_path, icon: "icons/lucide-store.svg", circle: "tw:bg-blue-600",
             frame: search_marketplace_path, frame_class: MARKETPLACE_FRAME_CLASS,
             eyebrow: translation(".marketplace_eyebrow"), title: translation(".marketplace_title"),
             body: translation(".marketplace_body"), action: translation(".marketplace_link")}]
        end

        def network
          [[translation(".network_shops_title"), translation(".network_shops")],
            [translation(".network_police_title"), translation(".network_police")],
            [translation(".network_universities_title"), translation(".network_universities")]]
        end
      end
    end
  end
end
