# frozen_string_literal: true

module Sessions
  module SignInInterstitial
    # Emailed links have to be GETs, so they land on a page that renders this and it posts
    # the token — a scanner or prefetcher following the link doesn't spend it.
    class Component < ApplicationComponent
      def initialize(url:, fields: {}, heading: nil, submit_text: nil, auto_submit: true)
        @url = url
        @fields = fields.compact_blank
        @heading = heading || translation("you_should_be_signed_in_automatically")
        @submit_text = submit_text || translation("sign_in")
        @auto_submit = auto_submit
      end
    end
  end
end
