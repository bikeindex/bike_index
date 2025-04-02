# frozen_string_literal: true

require "rails_helper"

RSpec.describe Alert::Component, type: :component do
  let(:options) { {text: "some text"} }
  let(:component) { render_inline(described_class.new(**options)) }

  it "renders" do
    expect(component).to be_present
    expect(component).to have_css('[role="alert"].tw\:text-blue-800')
    # It doesn't have dismissable button
    expect(component).to_not have_selector("button")
  end

  describe "error" do
    let(:options) { {text: "some text", kind: "error"} }
    it "renders" do
      expect(component).to have_content "some text"
      expect(component).to have_css('[role="alert"].tw\:text-red-800')
      # It doesn't have dismissable button
      expect(component).to_not have_selector("button")
    end
  end

  context "success dismissable" do
    let(:options) { {text: "some text", kind: "success", dismissable: true} }
    it "renders with dismissable" do
      expect(component).to have_content "some text"
      expect(component).to have_css('[role="alert"].tw\:text-green-800')
      # It has the dismissable button
      expect(component).to have_selector("button")
    end
  end
end
