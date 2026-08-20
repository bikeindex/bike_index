# frozen_string_literal: true

module PageBlock
  module Footer
    class Component < ApplicationComponent
      FACEBOOK_PIXEL_ID = "199066297131941"
      # Digest of the cached template — the cached_markup_digest spec keeps it current
      MARKUP_DIGEST = "052facf11cc3"

      def initialize(current_user:, skip_facebook:, passive_organization: nil)
        @current_user = current_user
        @skip_facebook = skip_facebook
        @passive_organization = passive_organization
      end

      private

      # No page_id: the links resolve their own active state in the browser and the locale
      # form submits to whatever URL it's on, so one render serves every page.
      # passive_organization because the Search link points at its registrations
      def cache_key
        [MARKUP_DIGEST, @current_user, @passive_organization, @skip_facebook]
      end
    end
  end
end
