# frozen_string_literal: true

module Form
  module Group
    class ComponentPreview < ApplicationComponentPreview
      # @!group Kinds
      def text_field
        {template: "form/group/component_preview/text_field"}
      end

      def email_field
        {template: "form/group/component_preview/email_field"}
      end

      def text_area
        {template: "form/group/component_preview/text_area"}
      end

      def custom_label
        {template: "form/group/component_preview/custom_label"}
      end
      # @!endgroup
    end
  end
end
