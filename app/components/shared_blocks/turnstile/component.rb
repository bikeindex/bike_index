# frozen_string_literal: true

module SharedBlocks
  module Turnstile
    class Component < ApplicationComponent
      # email: what the form was submitted with, so a browser that never ran the reveal
      # still gets the widget on the re-render rather than bouncing forever
      def initialize(email: nil)
        @email = email
      end

      def render? = Integrations::Turnstile.enabled?

      def call
        safe_join([tag.div(widget, class: wrapper_class, data: {turnstile_target: "widget"}), script])
      end

      private

      # Hidden until the turnstile controller sees an address worth asking, or until the
      # address already submitted is one - whichever gets there first
      def wrapper_class
        class_names("tw:my-4", "tw:hidden" => !Integrations::Turnstile.challenge?(@email))
      end

      def widget
        tag.div(class: "cf-turnstile", data: {sitekey: Integrations::Turnstile::SITE_KEY, theme: "auto"})
      end

      # defer rather than async - the widget above has to be in the DOM when it runs
      def script
        tag.script(src: "https://challenges.cloudflare.com/turnstile/v0/api.js", defer: true)
      end
    end
  end
end
