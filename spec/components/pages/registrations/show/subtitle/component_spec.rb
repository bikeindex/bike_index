require "rails_helper"

RSpec.describe Pages::Registrations::Show::Subtitle::Component, type: :component do
  let(:bike) { FactoryBot.create(:bike, name:) }
  let(:name) { "<b>Morning</b> commuter" }
  let(:component) { render_inline(described_class.new(bike:)) }

  it "renders the nickname" do
    expect(component).to have_text("nickname: <b>Morning</b> commuter")
  end

  context "without a name" do
    let(:name) { nil }

    it "renders nothing" do
      expect(component.to_html).to eq ""
    end
  end
end
