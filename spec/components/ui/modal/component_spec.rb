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
