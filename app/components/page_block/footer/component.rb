# frozen_string_literal: true

module PageBlock
  module Footer
    class Component < ApplicationComponent
      FACEBOOK_PIXEL_ID = "199066297131941"

      def initialize(current_user:, skip_facebook:, cache_key: nil)
        @current_user = current_user
        @skip_facebook = skip_facebook
        @cache_key = cache_key
      end
    end
  end
end
