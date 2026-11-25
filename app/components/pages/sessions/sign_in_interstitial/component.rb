# frozen_string_literal: true

module Pages
  module Sessions
    module SignInInterstitial
      # Emailed links have to be GETs, so they land here and post what the link carried. Scanners
      # run the page's JS too, so the form waits for a click rather than submitting on render
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
end
