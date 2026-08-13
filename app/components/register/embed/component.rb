# frozen_string_literal: true

module Register
  module Embed
    # The whole document for step 1 framed on an organization's landing page - rendered
    # with layout: false, since the embedding page is the chrome. It carries only what the
    # form itself needs: no nav, no footer, and no analytics, which the page around it counts.
    class Component < ApplicationComponent
      def initialize(b_param:, steps:, current_user: nil)
        @b_param = b_param
        @steps = steps
        @current_user = current_user
      end

      private

      def step_1
        render Register::Step1::Component.new(b_param: @b_param, steps: @steps,
          current_user: @current_user, embed: true)
      end
    end
  end
end
