require "rails_helper"

base_url = "/admin/mailchimp_values"
RSpec.describe Admin::MailchimpValuesController, type: :request do
  include_context :request_spec_logged_in_as_superuser

  describe "index" do
    it "renders" do
      get base_url
      expect(response.status).to eq(200)
      expect(response).to render_template(:index)
      expect(assigns(:mailchimp_values)).to eq([])
    end
  end

  describe "create" do
    it "updates all of them" do
      Sidekiq::Job.clear_all
      expect(UpdateMailchimpValuesJob.jobs.count).to eq 0
      post base_url
      expect(response).to redirect_to admin_mailchimp_values_path
      expect(flash[:success]).to be_present
      expect(UpdateMailchimpValuesJob.jobs.count).to eq 1
    end
  end
end
