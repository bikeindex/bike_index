require "rails_helper"

RSpec.describe RegistrationSequencePage, type: :model do
  describe "content" do
    let(:page) { FactoryBot.create(:registration_sequence_page, content: "<ul><li>one</li><li>two</li></ul>") }

    it "stores rich text content" do
      expect(page.content).to be_present
      expect(page.content.to_s).to include("<li>one</li>")
    end
  end
end
