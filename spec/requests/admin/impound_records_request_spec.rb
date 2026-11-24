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
    end

    context "saved before impounded_from_address_record existed" do
      let!(:impound_record) { FactoryBot.create(:impound_record_with_organization, :with_address_record) }

      it "renders where it was impounded from" do
        impound_record.update_column(:impounded_from_address_record_id, nil)
        get "#{base_url}/pkey-#{impound_record.id}"
        expect(response.status).to eq(200)
        expect(response.body).to include("1300 W 14th Pl")
        expect(response.body).to include("same as impounded from")
        expect(response.body).not_to include("No impounded from address")
      end
    end

    context "held at a location" do
      let(:location) { FactoryBot.create(:location, :with_address_record, address_in: :new_york, name: "Back lot") }
      let!(:impound_record) { FactoryBot.create(:impound_record_with_organization, :with_address_record, location:) }

      it "renders its current location apart from where it was impounded from" do
        get "#{base_url}/pkey-#{impound_record.id}"
        expect(response.body).to include("Back lot")
        expect(response.body).to include("278 Broadway")
        expect(response.body).to include("1300 W 14th Pl")
      end
    end
  end
end
