# frozen_string_literal: true

module Pages
  module Register
    module Views
      module Confirm
        # Where the emailed confirmation link lands. Confirming is single use and scanners run the
        # page's JS, so the form waits for a click rather than submitting on render
        # signed_in_as: someone else's account, which the registration finishes in
        # sign_out_to_agree: the owner has safety rules to agree to, so signed_in_as can't finish it
        class Component < ApplicationComponent
          def initialize(b_param:, token:, accept_terms: false, terms_checked: false, signed_in_as: nil,
            sign_out_to_agree: false)
            @b_param = b_param
            @token = token
            @accept_terms = accept_terms
            @terms_checked = terms_checked
            @signed_in_as = signed_in_as
            @sign_out_to_agree = sign_out_to_agree
          end
        end
      end
    end
  end
end
