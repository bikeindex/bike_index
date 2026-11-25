require "rails_helper"

base_url = "/admin/mailchimp_data"
RSpec.describe Admin::MailchimpDataController, type: :request do
  include_context :request_spec_logged_in_as_superuser

  describe "index" do
    it "renders" do
      get base_url
      expect(response.status).to eq(200)
      expect(response).to render_template(:index)
      expect(assigns(:mailchimp_data)).to eq([])
    end

    context "with data for a present and a soft-deleted user" do
      let(:subscribed_users) do
        %w[present@example.com deleted@example.com].map do |email|
          FactoryBot.create(:user, email:).tap do |user|
            FactoryBot.create(:membership, user:, level: "plus", start_at: Time.current - 1.year,
              end_at: Time.current + 2.weeks)
            MailchimpDatum.find_or_create_for(user.reload)
          end
        end
      end

      it "names both, marking the deleted one" do
        subscribed_users.last.destroy
        get base_url
        expect(response.status).to eq(200)
        expect(response.body).to include("present@example.com")
        expect(response.body).to include("deleted@example.com")
        expect(response.body).to include("user deleted")
      end
    end
  end
end
