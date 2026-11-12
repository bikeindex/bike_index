# frozen_string_literal: true

module Atoms
  module RegistrationStep
    # Where a registration stands in the register flow. Nothing for one the flow didn't start
    class Component < ApplicationComponent
      def initialize(b_param:)
        @b_param = b_param
      end

      def render? = step.present?

      def call = tag.span(label)

      private

      def label
        page_index = BikeServices::Register.page_index_for_step(step)
        return translation(".rules_page", number: page_index + 1) unless page_index.negative?

        case step
        when "1" then translation(".step_1")
        when "2" then translation(".step_2")
        when "report" then translation(".report")
        when "review" then translation(".review")
        # Without a bike, finished is entered and waiting on the email confirming the address
        else @b_param.with_bike? ? translation(".finished") : translation(".awaiting_email_confirmation")
        end
      end

      def step = @step ||= BikeServices::Register.current_step(@b_param)
    end
  end
end
