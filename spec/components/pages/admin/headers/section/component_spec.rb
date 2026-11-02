# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pages::Admin::Headers::Section::Component, type: :component do
  let(:options) { {title: "Bikes", count: 3, href: "/admin/bikes"} }
  let(:component) { render_inline(described_class.new(**options)) }

  it "links the count to the index" do
    expect(component.at_css("h2").text.squish).to eq "Bikes 3"
    expect(component).to have_link("3", href: "/admin/bikes")
  end

  context "without an href" do
    let(:options) { super().except(:href) }

    it "renders the count unlinked" do
      expect(component.at_css("h2").text.squish).to eq "Bikes 3"
      expect(component.css("a")).to be_empty
    end
  end

  context "without a count" do
    let(:options) { {title: "Edit Promoted Alert"} }

    it "renders the title alone" do
      expect(component.at_css("h2").text.squish).to eq "Edit Promoted Alert"
      expect(component.css("small")).to be_empty
    end
  end

  context "within another section" do
    let(:options) { {title: "Ban information", tag: :h3} }

    it "renders a smaller heading" do
      expect(component).to have_css("h3.tw\\:text-xl", text: "Ban information")
    end
  end

  context "with a parenthetical and block content" do
    let(:component) do
      render_inline(described_class.new(**options, parenthetical: "first 100 shown")) { "- more" }
    end

    it "wraps the parenthetical, and follows it with the content" do
      expect(component.at_css("h2").text.squish).to eq "Bikes 3 (first 100 shown) - more"
    end
  end
end
