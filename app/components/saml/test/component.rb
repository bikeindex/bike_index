# frozen_string_literal: true

module Saml
  module Test
    class Component < ApplicationComponent
      def initialize(organization:, result: nil, expected_email: nil)
        @organization = organization
        @result = result
        @expected_email = expected_email
      end

      private

      def diagnostic? = @result.is_a?(Saml::AssertionProcessor::DiagnosticResult)

      # The assertion carries whoever the IdP decided to release, not who was typed in
      def asserted_expected_email? = @expected_email == @result.email

      def summary_kind
        return :notice if @result.blank?

        @result.success? ? :success : :error
      end
    end
  end
end
