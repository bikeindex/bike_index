# frozen_string_literal: true

class ApplicationViewComponentPreview < ViewComponent::Preview
  include ActionView::Context

  # Don't include this class in Lookbook
  def self.abstract_class
    name == "ApplicationViewComponentPreview"
  end

  def self.inherited(subclass)
    super
    subclass.layout 'component_preview'
  end

  private

  def template
    ActionView::Base.new(
      ActionView::LookupContext.new(ActionController::Base.view_paths),
      {},
      ApplicationController.new
    )
  end
end
