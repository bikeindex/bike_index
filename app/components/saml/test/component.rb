# frozen_string_literal: true

module Saml
  module Test
    class Component < ApplicationComponent
      def initialize(organization:, result:)
        @organization = organization
        @result = result
      end

      def diagnostic?
        @result.respond_to?(:attributes)
      end
    end
  end
end
