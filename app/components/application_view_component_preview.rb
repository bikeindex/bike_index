# frozen_string_literal: true

class ApplicationViewComponentPreview < ViewComponent::Preview
  include ActionView::Context

  # Don't include this class in Lookbook
  def self.abstract_class
    name == "ApplicationViewComponentPreview"
  end
end
