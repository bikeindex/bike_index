# frozen_string_literal: true

require "rails_helper"

RSpec.describe UI::DragHandle::Component, type: :component do
  let(:instance) { described_class.new(**options) }
  let(:component) { render_inline(instance) }
  let(:options) { {controller: "sortable", label: "Color"} }

  it "renders a grip button targeting the controller's handle, its arrow keys calling moveByKey" do
    expect(component).to have_css("button[aria-label='Move Color']")
    expect(component).to have_css("button[type='button'][data-sortable-target='handle'][data-action='keydown->sortable#moveByKey']")
    expect(component).to have_css("button[data-moved-message='Position %{position} of %{count}']")
  end

  context "with a hyphenated controller and extra classes" do
    let(:options) { {controller: "bullet-editors", label: "bullet", html_class: "tw:pt-2"} }

    it "dasherizes the target key and appends the classes" do
      expect(component).to have_css("button[data-bullet-editors-target='handle'][data-action='keydown->bullet-editors#moveByKey'].tw\\:pt-2")
    end
  end
end
