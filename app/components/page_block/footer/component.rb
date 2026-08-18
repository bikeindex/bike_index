# frozen_string_literal: true

module PageBlock
  module Footer
    class Component < ApplicationComponent
      FACEBOOK_PIXEL_ID = "199066297131941"
      # Digest of the cached template — the cached_markup_digest spec keeps it current
      MARKUP_DIGEST = "82b456e191f5"

      def initialize(current_user:, skip_facebook:, page_id:, passive_organization: nil)
        @current_user = current_user
        @skip_facebook = skip_facebook
        @page_id = page_id
        @passive_organization = passive_organization
      end

      private

      def cache_key
        [MARKUP_DIGEST, @page_id, @current_user, @passive_organization, @skip_facebook]
      end
    end
  end
end
