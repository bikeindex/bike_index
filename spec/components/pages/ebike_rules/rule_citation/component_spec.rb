# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pages::EbikeRules::RuleCitation::Component, type: :component do
  let(:component) { render_inline(described_class.new(restriction:)) }
  let(:statute) { "https://leginfo.legislature.ca.gov/faces/codes_displaySection.xhtml?lawCode=VEH&sectionNum=21213" }
  let(:bill) { "https://leginfo.legislature.ca.gov/faces/billNavClient.xhtml?bill_id=202520260AB965" }

  context "with a citation and its source" do
    let(:restriction) { {citation: "California Vehicle Code §21213", sources: [statute]} }

    it "links the citation" do
      expect(component).to have_link("California Vehicle Code §21213", href: statute)
    end
  end

  context "with a citation and several sources" do
    let(:restriction) { {citation: "California Vehicle Code §§21212.5, 21213", sources: [statute, bill]} }

    it "follows the citation with a numbered link to each" do
      expect(component).to have_text("California Vehicle Code §§21212.5, 21213 1 2")
        .and have_link("1", href: statute).and have_link("2", href: bill)
        .and have_no_link("California Vehicle Code §§21212.5, 21213")
      expect(component).to have_css("a", count: 2)
    end
  end

  context "with sources and no citation" do
    let(:restriction) { {citation: nil, sources: [bill]} }

    it "links a source" do
      expect(component).to have_link("source", href: bill)
    end
  end

  context "with neither" do
    let(:restriction) { {rule: "Not a motor vehicle", citation: nil, sources: []} }

    it "renders nothing" do
      expect(component.to_html).to eq ""
    end
  end
end
