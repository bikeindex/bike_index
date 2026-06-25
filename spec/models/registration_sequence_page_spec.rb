require "rails_helper"

RSpec.describe RegistrationSequencePage, type: :model do
  describe "#htmlize_body" do
    let(:page) { FactoryBot.create(:registration_sequence_page, body: "## Hi\n\n- one\n- two") }

    it "renders body_html from Markdown on save" do
      expect(page.body_html).to match(/<h2.*>Hi<\/h2>/)
      expect(page.body_html).to include("<li>one</li>")
    end

    context "blank body" do
      let(:page) { FactoryBot.create(:registration_sequence_page, body: "") }

      it "leaves body_html nil" do
        expect(page.body_html).to be_nil
      end
    end
  end
end
