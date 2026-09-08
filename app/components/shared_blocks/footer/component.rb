# frozen_string_literal: true

module SharedBlocks
  module Footer
    class Component < ApplicationComponent
      FACEBOOK_PIXEL_ID = "199066297131941"
      # Digest of the cached template — the cached_markup_digest spec keeps it current
      MARKUP_DIGEST = "12bf831f75b7"

      def initialize(current_user:, skip_facebook:)
        @current_user = current_user
        @skip_facebook = skip_facebook
      end

      private

      # No page_id: the links resolve their own active state in the browser and the locale
      # form submits to whatever URL it's on, so one render serves every page
      def cache_key
        [MARKUP_DIGEST, @current_user, @skip_facebook]
      end
    end
  end
end
