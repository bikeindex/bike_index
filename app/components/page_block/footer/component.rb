# frozen_string_literal: true

module PageBlock
  module Footer
    class Component < ApplicationComponent
      FACEBOOK_PIXEL_ID = "199066297131941"
      # The cache key digests this markup, so edits invalidate themselves
      CACHED_MARKUP = "app/components/page_block/footer/**/*"

      def initialize(current_user:, skip_facebook:, page_id:, passive_organization: nil)
        @current_user = current_user
        @skip_facebook = skip_facebook
        @page_id = page_id
        @passive_organization = passive_organization
      end

      private

      def cache_key
        [self.class.markup_digest(CACHED_MARKUP), @page_id, @current_user, @passive_organization, @skip_facebook]
      end
    end
  end
end
