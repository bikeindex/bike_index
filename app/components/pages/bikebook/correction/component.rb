# frozen_string_literal: true

module Pages
  module Bikebook
    module Correction
      # A link at the bottom of the page and a dismissable floating button, each opening a form that files a BugReport
      class Component < ApplicationComponent
        MODAL_ID = "bikebook-correction"
        FORM_ID = "bikebook-correction-form"

        def initialize(user: nil)
          @user = user
        end

        private

        # Signing in first, back to the page with the form open, which bikebook--correction points at the page as it
        # is when clicked
        def trigger(text, color:, data: {}, **options)
          return render(UI::Button::Component.new(text:, color:, commandfor: MODAL_ID, command: "show-modal", data:, **options)) if @user

          render(UI::ButtonLink::Component.new(text:, color:, href: new_session_path(return_to: "#{bikebook_path}?modal_#{MODAL_ID}=1"),
            data: data.merge(action: "bikebook--correction#signIn"), **options))
        end
      end
    end
  end
end
