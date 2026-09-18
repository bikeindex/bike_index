require "rails_helper"

base_url = "/admin/impound_records"
RSpec.describe Admin::ImpoundRecordsController, type: :request do
  include_context :request_spec_logged_in_as_superuser

  describe "index" do
    let!(:impound_record) { FactoryBot.create(:impound_record) }
    it "renders" do
      get base_url
      expect(response.status).to eq(200)
      expect(response).to render_template(:index)
      expect(assigns(:impound_records)).to eq([impound_record])
    end
  end

  describe "show" do
    let!(:impound_record) { FactoryBot.create(:impound_record) }
    it "renders" do
      get "#{base_url}/pkey-#{impound_record.id}"
      expect(response.status).to eq(200)
      expect(response).to render_template(:show)
      expect(assigns(:impound_record).id).to eq impound_record.id
      # It works with just the bare ID too
      get "#{base_url}/#{impound_record.id}"
      expect(response.status).to eq(200)
      expect(response).to render_template(:show)
      expect(assigns(:impound_record).id).to eq impound_record.id
      expect(response.body).not_to include("created from a parking notification")
    end
    context "unregistered parking notification bike" do
      let(:parking_notification) { FactoryBot.create(:parking_notification_unregistered, kind: "impound_notification", created_at: Time.current - 1.hour) }
      let(:impound_record) do
        ProcessParkingNotificationJob.new.perform(parking_notification.id)
        parking_notification.reload.impound_record
      end
      it "renders the unregistered badge" do
        expect(impound_record.bike.creator_unregistered_parking_notification?).to be_truthy
        get "#{base_url}/pkey-#{impound_record.id}"
        expect(response.status).to eq(200)
        expect(response.body).to include("created from a parking notification")
      end
    end
  end
end
