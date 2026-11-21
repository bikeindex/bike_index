# frozen_string_literal: true

module Pages
  module Register
    module Views
      module Confirm
        # Where the emailed confirmation link lands. Confirming is single use and scanners run the
        # page's JS, so the form waits for a click rather than submitting on render
        class Component < ApplicationComponent
          def initialize(b_param:, token:, accept_terms: false)
            @b_param = b_param
            @token = token
            @accept_terms = accept_terms
          end
        end
      end
    end
  end
end
