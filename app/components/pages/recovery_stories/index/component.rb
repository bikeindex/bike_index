# frozen_string_literal: true

module Pages
  module RecoveryStories
    module Index
      class Component < ApplicationComponent
        REFERRAL_SOURCE = "recovery-stories"

        def initialize(recovery_displays:, pagy:, stripe_prices:, current_user: nil)
          @recovery_displays = recovery_displays
          @pagy = pagy
          @form = Pages::Donate::Form::Component.new(stripe_prices:, current_user:, referral_source: REFERRAL_SOURCE)
        end

        private

        def h2_classes = "tw:m-0 tw:font-header tw:font-extrabold tw:tracking-tight"
      end
    end
  end
end
