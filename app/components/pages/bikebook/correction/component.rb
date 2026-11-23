# frozen_string_literal: true

module Pages
  module Bikebook
    module Correction
      # A floating button opening a form that files a BugReport
      class Component < ApplicationComponent
        MODAL_ID = "bikebook-correction"
        FORM_ID = "bikebook-correction-form"

        def initialize(user: nil)
          @user = user
        end
      end
    end
  end
end
