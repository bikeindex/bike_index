# frozen_string_literal: true

module Emails
  module PartialRegistration
    class Component < ApplicationComponent
      def initialize(b_param:, email_preview: false)
        @b_param = b_param
        @email_preview = email_preview
      end

      private

      def organization
        @b_param.creation_organization
      end

      def color_and_brand
        [@b_param.primary_frame_color.presence, @b_param.mnfg_name].compact.join(" ")
      end

      def tokenized_url
        @email_preview ? OrganizedServices::EmailPreview::TOKEN_PATH : new_bike_url(b_param_token: @b_param.id_token)
      end

      def organization_snippet_body
        organization&.mail_snippet_body("partial_registration")
      end
    end
  end
end
