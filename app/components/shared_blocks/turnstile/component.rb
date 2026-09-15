# frozen_string_literal: true

module SharedBlocks
  module Turnstile
    class Component < ApplicationComponent
      # email: what the form was submitted with, so a browser that never ran the reveal
      # still gets the widget on the re-render rather than bouncing forever.
      # site_key: previews and the system spec pass Cloudflare's testing key
      def initialize(email: nil, site_key: nil)
        @email = email
        # Only falls back once the secret is set too - a half-configured Turnstile would
        # otherwise render a widget nothing verifies
        @site_key = site_key || (Integrations::Turnstile::SITE_KEY if Integrations::Turnstile.enabled?)
      end

      def render? = @site_key.present?

      def call
        safe_join([tag.div(widget, class: wrapper_class, data: {"shared-blocks--turnstile-target": "widget"}), script])
      end

      private

      # Hidden until the turnstile controller sees an address worth asking, or until the
      # address already submitted is one - whichever gets there first
      def wrapper_class
        class_names("tw:my-4", "tw:hidden" => !Integrations::Turnstile.risky_email?(@email))
      end

      def widget
        tag.div(class: "cf-turnstile", data: {sitekey: @site_key, theme: "auto"})
      end

      # defer rather than async - the widget above has to be in the DOM when it runs
      def script
        tag.script(src: "https://challenges.cloudflare.com/turnstile/v0/api.js", defer: true)
      end
    end
  end
end
