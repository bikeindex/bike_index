require "rails_helper"

RSpec.describe RegistrationSequencePage, type: :model do
  describe "#sanitize_body" do
    let(:page) { FactoryBot.create(:registration_sequence_page, body:) }
    let(:body) { "<ul><li>one</li><li><b>two</b><script>alert(1)</script></li></ul>" }

    it "strips disallowed tags on save" do
      expect(page.body).to include("<li>one</li>")
      expect(page.body).to include("<b>two</b>")
      expect(page.body).to_not include("script")
    end

    context "blank body" do
      let(:body) { nil }

      it "stays nil" do
        expect(page.body).to be_nil
      end
    end
  end
end
