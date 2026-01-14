# frozen_string_literal: true

module Emails::FinishedRegistration
  class ComponentPreview < ApplicationComponentPreview
    def default
      render(Emails::FinishedRegistration::Component.new(ownership:))
    end
  end
end
