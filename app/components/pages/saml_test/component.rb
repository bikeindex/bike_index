# frozen_string_literal: true

module Pages
  module SamlTest
    class Component < ApplicationComponent
      def initialize(organization:, result: nil, expected_email: nil)
        @organization = organization
        @result = result
        @expected_email = expected_email
      end

      private

      # email_attribute is set only once the signature validated, so its absence means
      # the assertion was rejected and there is nothing of it to report
      def asserted? = @result&.email_attribute.present?

      # The assertion carries whoever the IdP decided to release, not who was typed in
      def asserted_expected_email? = @expected_email == @result.email

      def summary_kind
        return :notice if @result.blank?

        @result.success? ? :success : :error
      end

      def summary_header
        return if @result.blank?
        return "You couldn't be signed in" unless @result.success?

        @result.signed_up ? "You were signed up successfully!" : "You were signed in successfully!"
      end
    end
  end
end
