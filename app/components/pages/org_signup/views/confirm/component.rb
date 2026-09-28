# frozen_string_literal: true

module Pages
  module OrgSignup
    module Views
      module Confirm
        # Where the emailed link lands. Confirming is single use and scanners run the
        # page's JS, so the form waits for a click rather than submitting on render
        class Component < ApplicationComponent
          def initialize(organization_signup:, token:)
            @organization_signup = organization_signup
            @token = token
          end
        end
      end
    end
  end
end
