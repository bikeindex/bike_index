# frozen_string_literal: true

module Pages
  module MyAccount
    module Show
      module BikeBox
        # A registration as a card, in a list row or a grid tile. The alerts render outside
        # the cache, since resolving or dismissing one doesn't touch the bike. Each is loaded
        # once for the page, and each box picks out its own
        class Component < ApplicationComponent
          VIEWS = %i[list grid].freeze

          # Literal strings so Tailwind's scanner generates them
          ACCENTS = {
            success: "tw:border-l-green-600", purple: "tw:border-l-purple-500", error: "tw:border-l-red-600",
            warning: "tw:border-l-amber-500", pink: "tw:border-l-pink-400"
          }.freeze

          def self.user_alerts(user)
            return [] unless user.alert_slugs.intersect?(UserAlert.account_kinds)

            user.user_alerts.active.account.includes(:organization)
          end

          def self.unfinished_b_params(bikes)
            BParam.acknowledgment_pending.where(created_bike_id: bikes.map(&:id)).order(:id).index_by(&:created_bike_id)
          end

          def initialize(bike:, current_user:, view: :list, user_alerts: [], unfinished_b_params: {})
            @bike = bike
            @current_user = current_user
            @view = VIEWS.include?(view&.to_sym) ? view.to_sym : :list
            @user_alerts = user_alerts.select { it.bike_id == bike.id }
            @unfinished_b_param = unfinished_b_params[bike.id]
          end

          private

          def cache_key
            [self.class.cache_digest, @view, @bike]
          end

          def grid? = @view == :grid

          def accent_classes = ACCENTS[Atoms::RegistrationStatusBadge::Component.color(@bike)]

          def thumb_image_url = @thumb_image_url ||= BikeServices::Displayer.thumb_image_url(@bike)

          # A bike with no photo links to where one is added
          def photo_path
            thumb_image_url ? bike_path(@bike) : edit_bike_path(@bike, edit_template: "photos")
          end

          # Only the exceptional statuses say when they began; being registered is the default
          def status_time = (@bike.occurred_at unless @bike.status_with_owner? && !@bike.is_for_sale?)

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
