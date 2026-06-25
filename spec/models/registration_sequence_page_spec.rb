require "rails_helper"

RSpec.describe RegistrationSequencePage, type: :model do
  describe "#normalize_bullet_points" do
    let(:page) { FactoryBot.create(:registration_sequence_page, bullet_points: bullet_points) }
    let(:bullet_points) { ["<p>one</p>", "<p></p>", "<b>two</b><script>alert(1)</script>", "  "] }

    it "sanitizes html and drops empty bullets on save" do
      expect(page.bullet_points.size).to eq(2)
      expect(page.bullet_points.first).to eq("<p>one</p>")
      expect(page.bullet_points.last).to include("<b>two</b>")
      expect(page.bullet_points.last).to_not include("script")
    end

    context "no bullet points" do
      let(:bullet_points) { [] }

      it "stores an empty array" do
        expect(page.bullet_points).to eq([])
      end
    end
  end
end
