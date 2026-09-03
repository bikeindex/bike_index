# frozen_string_literal: true

require "rails_helper"

RSpec.describe UI::Modal::Component, type: :component do
  let(:instance) { described_class.new(**options) }
  let(:options) { {id: "test-modal", title: "Test Modal"} }

  it "renders a dialog element" do
    component = render_inline(instance) do |modal|
      modal.with_body { "Body content" }
    end

    expect(component).to have_css("dialog#test-modal")
    expect(component).to have_css("[data-controller='ui--modal']")
    expect(component).to have_text("Test Modal")
    expect(component).to have_text("Body content")
    expect(component).to have_css("button[aria-label='Close']")
  end

  it "closes through the native command, and hears the browser's own open and close" do
    component = render_inline(instance) { |modal| modal.with_body { "Body" } }

    expect(component).to have_css("button[aria-label='Close'][commandfor='test-modal'][command='close']")
    action = component.css("dialog").attr("data-action").value
    expect(action).to include("close->ui--modal#closed")
    expect(action).to include("command->ui--modal#invoked")
  end

  it "does not flag open-on-connect by default" do
    component = render_inline(instance) { |modal| modal.with_body { "Body" } }
    expect(component).to have_css("dialog[data-ui--modal-open-on-connect-value='false']")
  end

  context "open" do
    let(:options) { {id: "open-modal", title: "Open Modal", open: true} }

    it "flags the controller to open it on connect" do
      component = render_inline(instance) { |modal| modal.with_body { "Body" } }
      expect(component).to have_css("dialog[data-ui--modal-open-on-connect-value='true']")
    end
  end

  context "without title" do
    let(:options) { {id: "no-title-modal"} }

    it "renders without title bar" do
      component = render_inline(instance) do |modal|
        modal.with_body { "Just body" }
      end

      expect(component).to have_css("dialog#no-title-modal")
      expect(component).not_to have_css("button[aria-label='Close']")
      expect(component).to have_text("Just body")
    end
  end
end
