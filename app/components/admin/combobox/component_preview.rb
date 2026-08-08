# frozen_string_literal: true

module Admin
  module Combobox
    class ComponentPreview < ApplicationComponentPreview
      # @!group Variants

      # No admin page matches the previewer's own URL, so the combobox prompts for one
      def default
        render(Admin::Combobox::Component.new)
      end

      # A developer additionally gets the "Dev:" pages
      def developer
        render(Admin::Combobox::Component.new(developer: true))
      end

      # @!endgroup
    end
  end
end
