# frozen_string_literal: true

module UI
  module Forms
    module Turnstile
      class Component < ApplicationComponent
        # api.js renders every .cf-turnstile it finds on load, so the controller appends it on
        # the first reveal rather than shipping it to everyone who opens the form
        SCRIPT_URL = "https://challenges.cloudflare.com/turnstile/v0/api.js"

        def initialize(email: nil)
          @email = email
        end

        def render? = Integrations::Turnstile::ENABLED

        def call
          safe_join([tag.div(widget, class: wrapper_class, data: {"ui--forms--turnstile-target": "widget"}),
            (script if already_risky?)].compact)
        end

        private

        # The address a challenged submission came back with - the widget and the script
        # both come from here, so a browser whose Stimulus never connects can still answer
        def already_risky? = EmailDomain.risky_email?(@email)

        def wrapper_class
          class_names("tw:my-4", "tw:hidden" => !already_risky?)
        end

        def widget
          tag.div(class: "cf-turnstile", data: {sitekey: Integrations::Turnstile::SITE_KEY, theme: "auto"})
        end

        def script
          tag.script(src: SCRIPT_URL, defer: true)
        end
      end
    end
  end
end
