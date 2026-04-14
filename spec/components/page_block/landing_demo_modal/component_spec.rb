# frozen_string_literal: true

require "rails_helper"

RSpec.describe PageBlock::LandingDemoModal::Component, type: :component do
  let(:instance) { described_class.new(**options) }
  let(:component) { render_inline(instance) }
  let(:options) { {feedback: Feedback.new, name_label: "School", feedback_type: "lead_for_school", modal_id: "schools-demo-modal"} }

  it "renders" do
    expect(component).to have_css("dialog")
    expect(component).to have_content("Contact us for a free trial")
    expect(component).to have_field("feedback_feedback_type", type: :hidden, with: "lead_for_school")
  end

  context "with law enforcement options" do
    let(:options) { {feedback: Feedback.new, name_label: "City", feedback_type: "lead_for_city", modal_id: "law-enforcement-demo-modal"} }

    it "renders" do
      expect(component).to have_css("dialog")
      expect(component).to have_field("feedback_feedback_type", type: :hidden, with: "lead_for_city")
    end
  end
end
