require "rails_helper"

base_url = "/admin/feedbacks"
RSpec.describe Admin::FeedbacksController, type: :request do
  let(:subject) { FactoryBot.create(:feedback) }
  include_context :request_spec_logged_in_as_superuser

  describe "index" do
    let!(:feedback) { FactoryBot.create(:feedback_serial_update_request) }

    it "renders" do
      get base_url
      expect(response.status).to eq(200)
      expect(response).to render_template(:index)
      expect(response.body).to include(feedback.name)
    end
  end

  describe "show" do
    it "renders" do
      get "#{base_url}/#{subject.to_param}"
      expect(response.status).to eq(200)
      expect(response).to render_template(:show)
    end
  end
end
