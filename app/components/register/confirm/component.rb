# frozen_string_literal: true

module Register
  module Confirm
    # Where the emailed confirmation link lands. Nothing is confirmed by rendering it -
    # the form posts itself, so a link scanner's GET can't spend the token
    class Component < ApplicationComponent
      # auto_submit off leaves the form for the preview, which has nothing to confirm
      def initialize(b_param:, token:, auto_submit: true)
        @b_param = b_param
        @token = token
        @auto_submit = auto_submit
      end
    end
  end
end
