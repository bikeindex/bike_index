# frozen_string_literal: true

module Pages
  module Bikebook
    module Correction
      # A floating button opening a form that files a BugReport. A signed-in user isn't asked for an email
      class Component < ApplicationComponent
        MODAL_ID = "bikebook-correction"

        def initialize(user: nil)
          @user = user
        end
      end
    end
  end
end
