# frozen_string_literal: true

module Pages
  module Register
    module Views
      module Landing
        # The marketing page for registering, with step 1 of the flow in its hero - which
        # posts into the flow itself, so everything after it is the flow's own steps
        class Component < ApplicationComponent
          BLANK_IMAGE = "data:image/gif;base64,R0lGODlhAQABAAAAACH5BAEKAAEALAAAAAABAAEAAAICTAEAOw=="
          REFERRAL_SOURCE = "register-landing"

          def initialize(b_param:, flow:, stripe_prices:, current_user: nil)
            @b_param = b_param
            @flow = flow
            @current_user = current_user
            @donate_form = Pages::Donate::Form::Component.new(stripe_prices:, current_user:, referral_source: REFERRAL_SOURCE)
          end

          def before_render
            helpers.content_for(:header) do
              tag.link(href: "https://fonts.googleapis.com/css2?family=Bangers&display=swap", rel: "stylesheet")
            end
          end

          private

          def checks
            [translation(".check_two_minutes"), translation(".check_free_no_data_sharing"), translation(".check_add_later")]
          end

          def benefits
            [{icon: "icons/file-check.svg", circle: "tw:bg-blue-600",
              title: translation(".benefit_proof_title"), body: translation(".benefit_proof_body")},
              {icon: "icons/siren.svg", circle: "tw:bg-[#cc0000]",
               title: translation(".benefit_alerts_title"), body: translation(".benefit_alerts_body")},
              {icon: "icons/searcher.svg", circle: "tw:bg-purple-500",
               title: translation(".benefit_resell_title"), body: translation(".benefit_resell_body")},
              {icon: "icons/bell-ring.svg", circle: "tw:bg-blue-500",
               title: translation(".benefit_found_title"), body: translation(".benefit_found_body")},
              {icon: "icons/repeat.svg", circle: "tw:bg-slate-900 tw:dark:bg-slate-600",
               title: translation(".benefit_transfer_title"), body: translation(".benefit_transfer_body")},
              {icon: "icons/shield-check.svg", circle: "tw:bg-[#ffd660] tw:text-slate-900!",
               title: translation(".benefit_private_title"), body: translation(".benefit_private_body")},
              {icon: "icons/lucide-store.svg", circle: "tw:bg-purple-500",
               title: translation(".benefit_marketplace_title"), body: translation(".benefit_marketplace_body")},
              {icon: "icons/users.svg", circle: "tw:bg-slate-900 tw:dark:bg-slate-600",
               title: translation(".benefit_network_title"), body: translation(".benefit_network_body")},
              {icon: "icons/smartphone.svg", circle: "tw:bg-blue-600",
               title: translation(".benefit_app_title"), body: translation(".benefit_app_body")}]
          end

          def stickers
            [{sound: translation(".sticker_register_sound"), color: "tw:text-blue-600",
              image: "kelsey/illustrations/comic-assets_u-lock.png",
              title: translation(".sticker_register_title"), body: translation(".sticker_register_body")},
              {sound: translation(".sticker_stolen_sound"), color: "tw:text-[#cc0000]",
               image: "kelsey/illustrations/comic-assets_presentation-stolenalert.png",
               title: translation(".sticker_stolen_title"), body: translation(".sticker_stolen_body")},
              {sound: translation(".sticker_flagged_sound"), color: "tw:text-purple-500",
               image: "kelsey/illustrations/comic-assets_bike-bell.png",
               title: translation(".sticker_flagged_title"), body: translation(".sticker_flagged_body")}]
          end

          def faqs
            [[translation(".faq_free_question"), translation(".faq_free_answer")],
              [translation(".faq_serial_question"), translation(".faq_serial_answer")],
              [translation(".faq_privacy_question"), translation(".faq_privacy_answer")]]
          end

          def band = "tw:border-gray-200 tw:bg-gray-50 tw:dark:border-gray-700 tw:dark:bg-gray-800/60"

          def section_inner = "tw:py-10 tw:sm:py-12 tw:lg:py-18 #{SharedBlocks::Marketing::Wrapper::Component::CONTAINER_CLASSES}"
        end
      end
    end
  end
end
