# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pages::LandingPages::DemoModal::Component, type: :component do
  let(:instance) { described_class.new(**options) }
  let(:component) { render_inline(instance) }
  let(:options) do
    {feedback:, name_label: "School", feedback_type: "lead_for_school", modal_id: "schools-demo-modal",
     return_to: "/for_schools"}
  end
  let(:feedback) { Feedback.new }

  it "renders" do
    expect(component).to have_css("dialog:not([data-ui--modal-open-on-connect-value='true'])")
    expect(component).to have_content("Contact us for a free trial")
    expect(component).to have_field("feedback_feedback_type", type: :hidden, with: "lead_for_school")
    expect(component).to have_field("return_to", type: :hidden, with: "/for_schools")
    expect(component).to have_no_field("feedback_body", type: :hidden)
    expect(component).to have_no_select("feedback_contact_role")
  end

  context "with role options and a lead that failed to save" do
    let(:options) { super().merge(role_options: [["City staff", "city_staff"]]) }
    let(:feedback) { Feedback.new(feedback_type: "lead_for_city", name: "Portland").tap(&:validate) }

    it "renders open, with the errors and the role select" do
      expect(component).to have_css("dialog[data-ui--modal-open-on-connect-value='true']")
      expect(component).to have_css("form[data-controller~='autofocus']")
      expect(component).to have_select("feedback_contact_role", options: ["", "City staff"])
      expect(component).to have_field("feedback_body", with: "")
    end
  end
end
