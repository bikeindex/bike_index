# frozen_string_literal: true

module Pages
  module OrgSignup
    module Views
      module Confirm
        # Where the emailed link lands. Confirming is single use and scanners run the
        # page's JS, so the form waits for a click rather than submitting on render.
        # signed_in_as: someone else's account, which activating signs out of
        class Component < ApplicationComponent
          def initialize(organization_signup:, token:, signed_in_as: nil)
            @organization_signup = organization_signup
            @token = token
            @signed_in_as = signed_in_as
          end
        end
      end
    end
  end
end
