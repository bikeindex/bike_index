# frozen_string_literal: true

module PageBlock
  module Footer
    class Component < ApplicationComponent
      FACEBOOK_PIXEL_ID = "199066297131941"

      def initialize(current_user:, skip_facebook:)
        @current_user = current_user
        @skip_facebook = skip_facebook
      end
    end
  end
end
