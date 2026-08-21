# frozen_string_literal: true

module Saml
  module Test
    class Component < ApplicationComponent
      def initialize(organization:, result: nil, email: nil, error: nil)
        @organization = organization
        @result = result
        @email = email
        @error = error
      end

      private

      def diagnostic? = @result.is_a?(Saml::AssertionProcessor::DiagnosticResult)

      # The assertion carries whoever the IdP decided to release, not who was typed in
      def asserted_expected_email?
        diagnostic? && @email.present? && @email == @result.email
      end

      def summary_kind
        return :error if @error.present?
        return :notice if @result.blank?

        @result.success? ? :success : :error
      end
    end
  end
end
