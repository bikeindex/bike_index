# frozen_string_literal: true

module UI::AlertForErrors
  class ComponentPreview < ApplicationComponentPreview
    def default
      render(UI::AlertForErrors::Component.new(object:, dismissable: true))
    end

    private

    def object
      object = EmailDomain.new(domain: "@whatever")
      object.valid?
      object
    end
  end
end
