# frozen_string_literal: true

module Pages
  module MyAccount
    module Show
      module BikeBox
        # A registration as a card in the list. The alerts render outside the cache, since
        # resolving or dismissing one doesn't touch the bike. Each is loaded once for the
        # page, and each box picks out its own
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

          # A link to the bike once it has a photo of its own; until then the frame holds the
          # add-photo button, which can't sit inside a link
          def photo_frame(&)
            classes = "tw:relative tw:flex tw:h-20 tw:w-28 tw:items-center tw:justify-center tw:overflow-hidden tw:rounded-lg tw:bg-gray-100 tw:@xl:row-span-2 tw:@xl:h-[124px] tw:@xl:w-[180px] tw:dark:bg-gray-900"
            return link_to(bike_path(@bike), class: classes, &) if @bike.thumb_path.present?

            tag.div(class: classes, &)
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
            return @location if defined?(@location)

            record = @bike.current_event_record
            @location = if record.blank? || @bike.is_for_sale
              nil
            elsif record.is_a?(ImpoundRecord)
              record.address_record&.formatted_address_string(visible_attribute: :street)
            else
              record.formatted_address_string
            end
          end

          def sale_link_text
            @bike.is_for_sale ? translation(".update_listing") : translation(".list_for_sale")
          end
        end
      end
    end
  end
end
