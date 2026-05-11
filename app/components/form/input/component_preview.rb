# frozen_string_literal: true

module Form
  module Input
    class ComponentPreview < ApplicationComponentPreview
      # @!group Kinds
      def text_field
        {template: "form/input/component_preview/text_field"}
      end

      def text_area
        {template: "form/input/component_preview/text_area"}
      end

      def email_field
        {template: "form/input/component_preview/email_field"}
      end

      def datetime_local_field
        {template: "form/input/component_preview/datetime_local_field"}
      end
      # @!endgroup
    end
  end
end
