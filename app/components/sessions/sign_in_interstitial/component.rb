# frozen_string_literal: true

module Sessions
  module SignInInterstitial
    # Emailed sign in links have to be GETs, so they land on a page that renders this and
    # it posts the token — a scanner or prefetcher following the link doesn't spend it.
    class Component < ApplicationComponent
      def initialize(url:, fields:, auto_submit: true)
        @url = url
        @fields = fields.compact_blank
        @auto_submit = auto_submit
      end
    end
  end
end
