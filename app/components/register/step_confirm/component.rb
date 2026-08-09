# frozen_string_literal: true

module Register
  module StepConfirm
    # Where the emailed confirmation link lands. Nothing is confirmed by rendering it -
    # confirming is single use, and a link scanner runs this page's JS, so the form waits
    # for a click rather than posting itself
    class Component < ApplicationComponent
      def initialize(b_param:, token:)
        @b_param = b_param
        @token = token
      end
    end
  end
end
