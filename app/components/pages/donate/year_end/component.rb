# frozen_string_literal: true

module Pages
  module Donate
    module YearEnd
      # The page the year-end appeal emails link to. The form is Pages::Donate::Form with this campaign's
      # presets; its source - the email's own, so each is told apart - names the audience. A source containing
      # "recovered" gets the recovered-bike headline and the 10% helper open.
      class Component < ApplicationComponent
        GOAL = 20_000
        REFERRAL_SOURCE = "eoy-2026"

        def initialize(stripe_prices:, initial_amount: nil, referral_source: nil, current_user: nil)
          @referral_source = referral_source.presence || REFERRAL_SOURCE
          @recovered = @referral_source.match?(/recovered/i)
          @form = Pages::Donate::Form::Component.new(stripe_prices:, initial_amount:, current_user:, referral_source: @referral_source,
            amounts: [50, 100, 250], default_cadence: :one_time, ten_percent: @recovered ? :open : :closed)
        end

        private

        def photos = Pages::Donate::Page::Component::WALL_PHOTOS

        def stats
          [[translation(".stat_recovered_figure"), translation(".stat_recovered")],
            [translation(".stat_value_figure"), translation(".stat_value")],
            [translation(".stat_registered_figure"), translation(".stat_registered")]]
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

        # position: where the screenshot's results start, so the card's short window shows bikes rather than the header
        def building
          [{image: "donate/year-end-bikebook.webp", alt: translation(".bikebook_image_alt"), position: "tw:object-[center_83%]",
            eyebrow: translation(".bikebook_eyebrow"), title: translation(".bikebook_title"),
            body: translation(".bikebook_body"), link_text: translation(".bikebook_link"), href: bikebook_path},
            {image: "donate/year-end-marketplace.webp", alt: translation(".marketplace_image_alt"), position: "tw:object-[center_89%]",
             eyebrow: translation(".marketplace_eyebrow"), title: translation(".marketplace_title"),
             body: translation(".marketplace_body"), link_text: translation(".marketplace_link"), href: search_marketplace_path}]
        end

        def network
          [[translation(".network_shops_title"), translation(".network_shops")],
            [translation(".network_police_title"), translation(".network_police")],
            [translation(".network_universities_title"), translation(".network_universities")]]
        end

        def other_ways
          [translation(".other_ways_match"), translation(".other_ways_daf"), translation(".other_ways_stock")]
        end
      end
    end
  end
end
