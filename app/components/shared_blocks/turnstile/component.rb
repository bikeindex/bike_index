# frozen_string_literal: true

module SharedBlocks
  module Turnstile
    class Component < ApplicationComponent
      def initialize(email: nil, site_key: Integrations::Turnstile.site_key)
        @email = email
        @site_key = site_key
      end

      def render? = @site_key.present?

      def call
        safe_join([tag.div(widget, class: wrapper_class, data: {"shared-blocks--turnstile-target": "widget"}),
          (script if already_risky?)].compact)
      end

      private

      # The address a challenged submission came back with - a browser that never ran the
      # reveal gets the widget from here rather than posting without a token forever
      def already_risky? = EmailDomain.risky_email?(@email)

      def wrapper_class
        class_names("tw:my-4", "tw:hidden" => !already_risky?)
      end

      def widget
        tag.div(class: "cf-turnstile", data: {sitekey: @site_key, theme: "auto"})
      end

      # api.js renders every .cf-turnstile it finds on load, so shipping it to everyone
      # would inject a cross-origin iframe on two of the busiest forms. The controller
      # appends it on reveal instead
      def script
        tag.script(src: Integrations::Turnstile::SCRIPT_URL, defer: true)
      end
    end
  end
end
