# frozen_string_literal: true

module Registrations
  module Show
    module Wrapper
      # Renders the registration show page as the resolved [kind, organization]
      # perspective (e.g. [:public, nil] or [:staff, org]) and fragment-caches it.
      class Component < ApplicationComponent
        # Digest of the markup inside the cache block — the cached_markup_digest spec
        # keeps it current, following what this tree renders out into UI:: and elsewhere
        MARKUP_DIGEST = "755822ae02b3"

        def initialize(bike:, current_user:, view:, available_views:, bike_sticker: nil, current_alerts: nil)
          @bike = bike
          @current_user = current_user
          @view = view
          @available_views = available_views
          @bike_sticker = bike_sticker
          @current_alerts = current_alerts
        end

        # The dialog renders outside the cache block — it's per-request, so caching it
        # would serve one token-holder's modal to every later viewer. It's the prompt the
        # key already resolved, rather than a second selection pass over the same tokens
        def call
          safe_join([
            token_prompt ? render(token_prompt) : "",
            capture { cache(cache_key) { concat(render(inner_component)) } }
          ])
        end

        # Keyed on the viewer for the admin view's per-user content. The bike's
        # cache version misses org-scoped records that don't touch the bike (notes,
        # model audits, the owner's other registrations), so the inner component
        # folds their versions in via #cache_version. This key can't keep cached
        # forms' CSRF tokens valid (they're session-scoped, and a user's session
        # varies across devices/logins) — the csrf-refresh controller reissues them
        # client-side from the meta tag.
        #
        # The ownership's timestamp is in here because claiming doesn't touch the bike,
        # and both views show claim state.
        #
        # The prompt's alert sits in the cached body, so the prompt a request earned is
        # in the key too — identified, not just typed, or one recipient's alert (and the
        # token in its form) would be served to the next. Nil for every request without
        # a prompt, which is nearly all of them.
        def cache_key
          [MARKUP_DIGEST, @current_user&.id,
            @current_user&.registration_show_toggleable?, @current_user&.feature_registration_show_legacy?,
            BikeServices::ShowViews.view_param(@view), @bike_sticker&.id,
            @bike.current_ownership&.updated_at, token_prompt && @current_alerts.cache_key,
            @bike.cache_key_with_version, *inner_component.try(:cache_version)]
        end

        private

        def token_prompt
          return @token_prompt if defined?(@token_prompt)

          @token_prompt = CurrentAlerts::TokenPrompt::Component.prompt_for(bike: @bike,
            current_user: @current_user, current_alerts: @current_alerts)
        end

        def inner_component
          @inner_component ||= begin
            kind, organization = @view
            if organization
              WrapperOrgAdmin::Component.new(bike: @bike, current_user: @current_user, organization:,
                org_role: kind, available_views: @available_views, bike_sticker: @bike_sticker,
                current_alerts: @current_alerts)
            else
              WrapperConsumer::Component.new(bike: @bike, current_user: @current_user, owner: kind == :owner,
                show_for_sale: @bike.is_for_sale?, available_views: @available_views, bike_sticker: @bike_sticker,
                current_alerts: @current_alerts)
            end
          end
        end
      end
    end
  end
end
