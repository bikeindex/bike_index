# frozen_string_literal: true

class ApplicationComponentPreview < ViewComponent::Preview
  include ActionView::Context

  # Don't include this class in Lookbook
  def self.abstract_class
    name == "ApplicationComponentPreview"
  end

  def self.inherited(subclass)
    super
    subclass.layout "component_preview"
  end

  # Falls back like lookbook_organization — a fresh database should render, not raise
  def lookbook_user
    @lookbook_user ||= User.find_by(id: ENV.fetch("LOOKBOOK_USER_ID", 1)) || User.first
  end

  def lookbook_organization
    @lookbook_organization ||= Organization.friendly_find("brakebills") || Organization.first
  end

  private

  def production_notice(rendered)
    render(UI::Alerts::Base::Component.new(kind: :error,
      text: "This preview renders a real #{rendered}, so it's disabled in production."))
  end

  def missing_notice(needed)
    render(UI::Alerts::Base::Component.new(kind: :warning,
      text: "Nothing to preview — this environment has no #{needed}."))
  end

  def template
    ActionView::Base.new(
      ActionView::LookupContext.new(ActionController::Base.view_paths),
      {},
      ApplicationController.new
    )
  end
end
