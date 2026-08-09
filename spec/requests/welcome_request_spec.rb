require "rails_helper"

RSpec.describe "Welcome", type: :request do
  describe "recovery_stories" do
    let(:quote) { "I got it back <script>alert(1)</script>" }
    let!(:recovery_display) { FactoryBot.create(:recovery_display, quote:) }

    it "escapes the quote" do
      get "/recovery_stories"
      expect(response.status).to eq(200)
      expect(response.body).to_not include("<script>alert(1)</script>")
      expect(response.body).to include(ERB::Util.html_escape(quote))
    end
  end
end
