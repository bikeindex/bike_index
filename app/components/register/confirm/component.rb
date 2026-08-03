# frozen_string_literal: true

module Register
  module Confirm
    # Where the emailed confirmation link lands. Nothing is confirmed by rendering it -
    # the form posts itself, so a link scanner's GET can't spend the token
    class Component < ApplicationComponent
      def initialize(b_param:, token:)
        @b_param = b_param
        @token = token
      end
    end
  end
end
