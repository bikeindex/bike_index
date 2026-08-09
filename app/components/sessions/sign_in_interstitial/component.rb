# frozen_string_literal: true

module Sessions
  module SignInInterstitial
    # Emailed links have to be GETs, so they land on a page that renders this and it posts
    # the token. Scanners follow the link and run its JS, so anything the POST spends has to
    # wait for a click — auto_submit is only for actions that are safe to repeat.
    class Component < ApplicationComponent
      def initialize(url:, fields: {}, heading: nil, submit_text: nil, auto_submit: false)
        @url = url
        @fields = fields.compact_blank
        @heading = heading || translation("finish_signing_in")
        @submit_text = submit_text || translation("sign_in")
        @body = translation(auto_submit ? "if_not_click_button" : "click_button_to_continue")
        @auto_submit = auto_submit
      end
    end
  end
end
