# frozen_string_literal: true

module Emails
  module PartialRegistration
    class Component < ApplicationComponent
      def initialize(b_param:, email_preview: false, email_preview_tokenized_url: nil)
        @b_param = b_param
        @email_preview = email_preview
        @email_preview_tokenized_url = email_preview_tokenized_url
      end

      private

      def organization
        @b_param.creation_organization
      end

      def color_and_brand
        parts = []
        parts << Color.find(@b_param.primary_frame_color_id)&.name if @b_param.primary_frame_color_id.present?
        parts << @b_param.mnfg_name
        parts.compact.join(" ")
      end

      def tokenized_url
        @email_preview ? @email_preview_tokenized_url : new_bike_url(b_param_token: @b_param.id_token)
      end

      def organization_snippet_body
        organization&.mail_snippet_body("partial_registration")
      end
    end
  end
end
