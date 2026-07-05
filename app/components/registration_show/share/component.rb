# frozen_string_literal: true

module RegistrationShow
  module Share
    # A share button that uses the Web Share API, falling back to copying the URL
    class Component < ApplicationComponent
      def initialize(text:, url:)
        @text = text
        @url = url
      end
    end
  end
end
