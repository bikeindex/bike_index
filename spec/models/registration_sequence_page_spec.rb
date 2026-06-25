require "rails_helper"

RSpec.describe RegistrationSequencePage, type: :model do
  describe "#normalize_bullet_points" do
    let(:page) { FactoryBot.create(:registration_sequence_page, bullet_points: ["  one  ", "", "two", "  "]) }

    it "strips whitespace and drops blank bullets on save" do
      expect(page.bullet_points).to eq(["one", "two"])
    end

    context "no bullet points" do
      let(:page) { FactoryBot.create(:registration_sequence_page, bullet_points: []) }

      it "stores an empty array" do
        expect(page.bullet_points).to eq([])
      end
    end
  end
end
