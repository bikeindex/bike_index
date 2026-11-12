# frozen_string_literal: true

require "rails_helper"

RSpec.describe UI::Accordion::Component, type: :component do
  let(:component) { render_inline(described_class.new(items: [["First question", "First answer"], ["Second question", "Second answer"]])) }

  it "renders each question as a collapse trigger, with only the first answer open" do
    expect(component).to have_css("[data-controller='ui--collapse'] [role='button'] [data-ui--collapse-target='chevron'] + span", text: "First question")
    expect(component).to have_css("[data-ui--collapse-target='content']:not(.tw\\:hidden)", text: "First answer")
    expect(component).to have_css("[data-ui--collapse-target='content'].tw\\:hidden", text: "Second answer", visible: :all)
  end
end
