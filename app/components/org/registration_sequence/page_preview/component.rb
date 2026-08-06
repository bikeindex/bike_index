# frozen_string_literal: true

module Org
  module RegistrationSequence
    module PagePreview
      # A single sequence page shown as a registrant sees it (via Register::PageContent),
      # with decorative checkboxes. Used in the full preview and beneath the page editor.
      class Component < ApplicationComponent
        # first: the flow's opening page, where the registrant is told why these appeared
        def initialize(page:, first: false)
          @page = page
          @first = first
        end
      end
    end
  end
end
