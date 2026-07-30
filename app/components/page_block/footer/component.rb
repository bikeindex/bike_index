# frozen_string_literal: true

module PageBlock
  module Footer
    class Component < ApplicationComponent
      FACEBOOK_PIXEL_ID = "199066297131941"
      # Nothing digests the cached template, so the key carries a digest of it instead.
      # The cached_markup_digest spec keeps MARKUP_DIGEST current.
      CACHED_MARKUP = "app/components/page_block/footer/**/*"
      MARKUP_DIGEST = "d60f31315138"

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
