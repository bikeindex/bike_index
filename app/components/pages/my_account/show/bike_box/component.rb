# frozen_string_literal: true

module Pages
  module MyAccount
    module Show
      module BikeBox
        # A registration as a card in the list. The alerts render outside
        # the cache, since resolving or dismissing one doesn't touch the bike. Each is loaded
        # once for the page, and each box picks out its own
        class Component < ApplicationComponent
          def self.user_alerts(user)
            return [] unless user.alert_slugs.intersect?(UserAlert.account_kinds)

            user.user_alerts.active.account.includes(:organization)
          end

          def self.unfinished_b_params(bikes, user)
            BParam.acknowledgment_pending.where(created_bike_id: bikes.map(&:id)).order(:id)
              .select { it.unfinished_registration?(user) }.index_by(&:created_bike_id)
          end

          def initialize(bike:, current_user:, user_alerts: [], unfinished_b_params: {})
            @bike = bike
            @current_user = current_user
            @user_alerts = user_alerts.select { it.bike_id == bike.id }
            @unfinished_b_param = unfinished_b_params[bike.id]
          end

          private

          def cache_key
            [self.class.cache_digest, @bike, impound_claim]
          end

          def accent_classes = Atoms::RegistrationStatusBadge::Component.border_class(@bike)

          def thumb_image_url
            @thumb_image_url ||= @bike.public_images.first&.image_url(:small) || BikeServices::Displayer.thumb_image_url(@bike)
          end

          # A stock photo fills the frame, but the owner still hasn't added one of their own
          def photo_path
            @bike.thumb_path.present? ? bike_path(@bike) : edit_bike_path(@bike, edit_template: "photos")
          end

          def add_photo_prompt
            return if @bike.thumb_path.present?

            tag.span(render(UI::Badge::Component.new(text: translation(".add_a_photo"), color: :empty)), class: "tw:absolute tw:bottom-2 tw:left-2")
          end

          def strava_gear_link
            strava_gear = @bike.strava_gear
            return unless @bike.status_with_owner? && strava_gear.present?

            link_to(strava_search_path(gear: strava_gear.strava_id), class: "tw:inline-flex tw:items-center tw:gap-1 tw:text-sm tw:text-gray-500 tw:dark:text-gray-400") do
              safe_join([helpers.inline_svg_tag("logos/strava-symbol.svg", class: "tw:size-3.5", aria_hidden: true), strava_gear.strava_gear_display_name])
            end
          end

          def impound_claim
            return @impound_claim if defined?(@impound_claim)

            @impound_claim = (@bike.impound_claims_submitting.active.last if @bike.status_stolen?)
          end

          def impound_claim_note
            claimed_bike = impound_claim&.bike_claimed
            return if claimed_bike.blank?

            claimed_bike_link = link_to(translation(".this_claimed_bike_type", kind: impound_claim.kind, bike_type: claimed_bike.type),
              bike_path(claimed_bike), class: "twlink-underlined")
            tag.div(translation(".impound_claim_html", status: impound_claim.status_humanized.titleize, claimed_bike: claimed_bike_link),
              class: "tw:text-sm tw:text-yellow-800 tw:dark:text-yellow-300")
          end

          def bike_sticker_codes
            @bike_sticker_codes ||= @bike.bike_stickers.includes(:bike_sticker_batch).map(&:pretty_code)
          end

          # A marketplace listing shows its own address
          def location
            record = @bike.current_event_record
            return if record.blank? || @bike.is_for_sale
            return record.formatted_address_string unless record.is_a?(ImpoundRecord)

            record.address_record&.formatted_address_string(visible_attribute: :street)
          end

          def sale_link_text
            @bike.is_for_sale ? translation(".update_listing") : translation(".list_for_sale")
          end

          def title_html
            safe_join([tag.strong([@bike.year, @bike.mnfg_name].compact.join(" ")), @bike.frame_model_truncated.presence].compact, " ")
          end
        end
      end
    end
  end
end
