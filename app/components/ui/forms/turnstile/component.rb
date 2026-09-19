# frozen_string_literal: true

module UI
  module Forms
    module Turnstile
      class Component < ApplicationComponent
        SCRIPT_URL = "https://challenges.cloudflare.com/turnstile/v0/api.js"

        # The values its controller reads off the form. The reveal skips user's confirmed
        # addresses, the way Integrations::Turnstile skips them on submit
        def self.form_data(user: nil)
          {"ui--forms--turnstile-domains-value": EmailDomain::RISKY_EMAIL_DOMAINS.to_json,
           "ui--forms--turnstile-script-url-value": SCRIPT_URL,
           "ui--forms--turnstile-exempt-emails-value": (user&.confirmed_emails || []).to_json}
        end

        def initialize(email: nil, user: nil)
          @email = email
          @user = user
        end

        def render? = Integrations::Turnstile::ENABLED

        def call
          return wrapper unless challenged?

          safe_join([wrapper, no_js_alert, script])
        end

        private

        # The address a challenged submission came back with - the widget and the script
        # both come from here, so a browser whose Stimulus never connects can still answer.
        # Still rendered hidden when it's false: the rider can type a challenged address next
        def challenged? = Integrations::Turnstile.challenge?(@email, user: @user)

        def wrapper
          tag.div(widget, class: wrapper_class, data: {"ui--forms--turnstile-target": "widget"})
        end

        def wrapper_class
          class_names("tw:my-4", "tw:hidden" => !challenged?)
        end

        def widget
          tag.div(class: "cf-turnstile", data: {sitekey: Integrations::Turnstile::SITE_KEY, theme: "auto"})
        end

        def script
          tag.script(src: SCRIPT_URL, defer: true)
        end

        # api.js is what draws the widget, so scripting off leaves nothing to answer.
        # A warning rather than an error - the error above it already says the submission failed
        def no_js_alert
          tag.noscript(render(UI::Alerts::Base::Component.new(kind: :warning,
            text: translation(".enable_javascript"))))
        end
      end
    end
  end
end
