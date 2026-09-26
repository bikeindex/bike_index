# frozen_string_literal: true

module Pages
  module Register
    module Landing
      # The marketing page for registering, with step 1 of the flow in its hero - which
      # posts into the flow itself, so everything after it is the flow's own steps
      class Component < ApplicationComponent
        def initialize(b_param:, steps:, recoveries_count:, recoveries_value:, organizations_count:,
          bikes_count:, current_user: nil)
          @b_param = b_param
          @steps = steps
          @current_user = current_user
          @recoveries_count = recoveries_count
          @recoveries_value = recoveries_value
          @organizations_count = organizations_count
          @bikes_count = bikes_count
        end

        def before_render
          helpers.content_for(:header) do
            tag.link(href: "https://fonts.googleapis.com/css2?family=Bangers&display=swap", rel: "stylesheet")
          end
        end

        private

        def checks
          [translation(".check_two_minutes"), translation(".check_free_forever"), translation(".check_add_later")]
        end

        def stats
          [{value: number_display(@bikes_count), label: translation(".stat_bikes_registered")},
            {value: number_display(@recoveries_count), label: translation(".stat_bikes_recovered")},
            {value: render(Atoms::CurrencyMillions::Component.new(dollars_usd: @recoveries_value)),
             label: translation(".stat_value_returned")},
            {value: safe_join([number_display(@organizations_count), "+"]), label: translation(".stat_partners")}]
        end

        def benefits
          [{icon: "icons/file-check.svg", circle: "tw:bg-blue-600 tw:text-white",
            title: translation(".benefit_proof_title"), body: translation(".benefit_proof_body")},
            {icon: "icons/siren.svg", circle: "tw:bg-[#cc0000] tw:text-white",
             title: translation(".benefit_alerts_title"), body: translation(".benefit_alerts_body")},
            {icon: "icons/searcher.svg", circle: "tw:bg-purple-500 tw:text-white",
             title: translation(".benefit_resell_title"), body: translation(".benefit_resell_body")},
            {icon: "icons/bell-ring.svg", circle: "tw:bg-blue-500 tw:text-white",
             title: translation(".benefit_found_title"), body: translation(".benefit_found_body")},
            {icon: "icons/repeat.svg", circle: "tw:bg-slate-900 tw:text-white",
             title: translation(".benefit_transfer_title"), body: translation(".benefit_transfer_body")},
            {icon: "icons/shield-check.svg", circle: "tw:bg-[#ffd660] tw:text-slate-900",
             title: translation(".benefit_private_title"), body: translation(".benefit_private_body")},
            {icon: "icons/store.svg", circle: "tw:bg-purple-500 tw:text-white",
             title: translation(".benefit_marketplace_title"), body: translation(".benefit_marketplace_body")},
            {icon: "icons/users.svg", circle: "tw:bg-slate-900 tw:text-white",
             title: translation(".benefit_network_title"), body: translation(".benefit_network_body")},
            {icon: "icons/smartphone.svg", circle: "tw:bg-blue-600 tw:text-white",
             title: translation(".benefit_app_title"), body: translation(".benefit_app_body")}]
        end

        def stickers
          [{sound: translation(".sticker_register_sound"), color: "tw:text-blue-600",
            image: "register_landing/u-lock.png",
            title: translation(".sticker_register_title"), body: translation(".sticker_register_body")},
            {sound: translation(".sticker_stolen_sound"), color: "tw:text-[#cc0000]",
             image: "register_landing/stolen-alert.png",
             title: translation(".sticker_stolen_title"), body: translation(".sticker_stolen_body")},
            {sound: translation(".sticker_flagged_sound"), color: "tw:text-purple-500",
             image: "register_landing/bike-bell.png",
             title: translation(".sticker_flagged_title"), body: translation(".sticker_flagged_body")}]
        end

        def faqs
          [[translation(".faq_free_question"), translation(".faq_free_answer")],
            [translation(".faq_serial_question"), translation(".faq_serial_answer")],
            [translation(".faq_privacy_question"), translation(".faq_privacy_answer")]]
        end

        def section_inner = "tw:mx-auto tw:max-w-6xl tw:px-5 tw:py-12 tw:lg:px-6 tw:lg:py-18"

        def h2_classes = "tw:m-0 tw:font-header tw:text-[28px] tw:leading-tight tw:font-extrabold tw:text-slate-900 tw:lg:text-[38px]"
      end
    end
  end
end
