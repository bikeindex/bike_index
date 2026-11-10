# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pages::Register::Parts::AcknowledgmentCheck::Component, type: :component do
  let(:education_course) { FactoryBot.create(:education_course, acknowledgment_text: "agree to the rules.") }

  it "signs with the registrant's name and submits under the given name" do
    render_inline(described_class.new(course: education_course, registrant_name: "Alice Quinn",
      checkbox_name: :acknowledged_all))

    expect(page).to have_css("strong", text: "Alice Quinn")
    expect(page).to have_content("agree to the rules.")
    expect(page).to have_css("input[type=checkbox][name='acknowledged_all']")
  end

  it "stands in a placeholder when nobody is signing" do
    render_inline(described_class.new(course: education_course))

    expect(page).to have_css("em", text: "registrant's name")
    expect(page).to have_css("input[type=checkbox]:not([name])")
  end
end
