# frozen_string_literal: true

module PageBlock
  module Footer
    class Component < ApplicationComponent
      FACEBOOK_PIXEL_ID = "199066297131941"

      def initialize(controller_namespace:, controller_name:, current_user:, params:)
        @controller_namespace = controller_namespace
        @controller_name = controller_name
        @current_user = current_user
        @params = params
      end

      private

      # Meta blocks these params (search_email is PII); the pixel auto-sends the
      # URL query string, so don't load it when they're present
      def skip_facebook?
        @controller_namespace.in?(%w[organized org_public oauth]) ||
          @controller_name == "organizations" ||
          @params.key?(:search_email) || @params.key?(:proximity)
      end
    end
  end
end
