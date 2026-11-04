# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pages::Admin::Headers::Count::Component, type: :component do
  let(:options) { {count: 3, href: "/admin/bikes"} }
  let(:component) { render_inline(described_class.new(**options)) }

  it "links the count to the index" do
    expect(component.text.squish).to eq "3"
    expect(component).to have_link("3", href: "/admin/bikes")
  end

  context "without an href" do
    let(:options) { {count: 3} }

    it "renders the count unlinked" do
      expect(component.text.squish).to eq "3"
      expect(component.css("a")).to be_empty
    end
  end

  context "with a suffix" do
    let(:options) { {count: 3, href: "/admin/bikes", suffix: "in the past week"} }

    it "follows the count, outside its link" do
      expect(component.text.squish).to eq "3 in the past week"
      expect(component).to have_link("3", href: "/admin/bikes", exact: true)
    end
  end

  context "with a parenthetical" do
    let(:options) { {count: 3, parenthetical: "first 100 shown"} }

    it "wraps the parenthetical" do
      expect(component.text.squish).to eq "3 (first 100 shown)"
    end
  end
end
