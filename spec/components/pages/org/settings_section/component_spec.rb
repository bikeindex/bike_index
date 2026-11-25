# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pages::Org::SettingsSection::Component, type: :component do
  let(:component) { render_inline(described_class.new(**options)) { "The fields" } }
  let(:options) { {title: "Profile", description: "How it appears"} }

  it "renders the title, description and fields" do
    expect(component).to have_css("h2", text: "Profile")
    expect(component).to have_css("p", text: "How it appears")
    expect(component).to have_content("The fields")
  end

  context "without a description" do
    let(:options) { {title: "Profile"} }

    it "renders no description" do
      expect(component).to have_css("h2", text: "Profile")
      expect(component).to have_no_css("p")
    end
  end
end
