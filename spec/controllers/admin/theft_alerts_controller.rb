require "rails_helper"

RSpec.describe Admin::TheftAlertsController, type: :controller do
  include_context :logged_in_as_super_admin
  let(:stolen_record) { FactoryBot.create(:stolen_record_recovered) }
  let(:ownership) { FactoryBot.create(:ownership) }
  let(:user) { ownership.creator }
  let(:bike) { ownership.bike }
  let!(:theft_alert) { FactoryBot.create(:theft_alert, stolen_record: stolen_record) }
  describe "update" do
    it "sends an email when status is updated" do
      ActionMailer::Base.deliveries = []
      put :update, id: theft_alert.id, status: "active"
      expect(response.status).to eq(200)
      expect(ActionMailer::Base.deliveries).not_to be_empty
    end
  end
end
