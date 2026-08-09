# frozen_string_literal: true

module Sessions
  module SignInInterstitial
    # Emailed links have to be GETs, so they land on a page that renders this and it posts
    # what the link carried. Scanners follow the link and run its JS, so the form waits for a
    # click — submitting on render would let them spend the token, or unsubscribe the reader.
    class Component < ApplicationComponent
      def initialize(url:, fields: {}, heading: nil, submit_text: nil)
        @url = url
        @fields = fields.compact_blank
        @heading = heading || translation("finish_signing_in")
        @submit_text = submit_text || translation("sign_in")
      end
    end
  end
end
