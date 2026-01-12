require "rails_helper"

RSpec.describe Admin::BikesController, type: :request do
  base_url = "/admin/bikes"
  let(:bike) { FactoryBot.create(:bike, :with_ownership) }
  include_context :request_spec_logged_in_as_superuser

  describe "index" do
    it "renders" do
      get base_url
      expect(response.code).to eq("200")
      expect(response).to render_template("index")
      expect(flash).to_not be_present
      expect(assigns(:page_id)).to eq "admin_bikes_index"
    end
  end

  describe "duplicates" do
    it "renders" do
      get "#{base_url}/duplicates"
      expect(response.code).to eq("200")
      expect(response).to render_template("duplicates")
      expect(flash).to_not be_present
    end
  end

  describe "edit" do
    let(:bike) { FactoryBot.create(:stolen_bike) }
    let(:stolen_record) { bike.current_stolen_record }
    context "standard" do
      it "renders" do
        get "#{base_url}/#{FactoryBot.create(:bike).id}/edit"
        expect(response.code).to eq("200")
        expect(response).to render_template("edit")
        expect(flash).to_not be_present
        expect(assigns(:page_id)).to eq "admin_bikes_edit"
      end
    end
    context "with recovery" do
      before { stolen_record.add_recovery_information }
      it "includes recovery" do
        get "#{base_url}/#{bike.id}/edit"
        expect(response.code).to eq("200")
        expect(response).to render_template("edit")
        expect(flash).to_not be_present
        expect(assigns(:recoveries)).to eq bike.recovered_records
        expect(assigns(:recoveries).pluck(:id)).to eq([stolen_record.id])
      end
    end
  end

  describe "show" do
    it "renders if given active_tab" do
      # Redirects if no active tab
      get "#{base_url}/#{bike.id}"
      expect(response).to redirect_to("#{base_url}/#{bike.id}/edit")
      # Otherwise, it renders
      get "#{base_url}/#{bike.id}?active_tab=messages"
      expect(response.code).to eq("200")
      expect(flash).to_not be_present
      get "#{base_url}/#{bike.id}?active_tab=stickers"
      expect(response.code).to eq("200")
      get "#{base_url}/#{bike.id}?active_tab=ownerships"
      expect(response.code).to eq("200")
      get "#{base_url}/#{bike.id}?active_tab=recoveries"
      expect(response.code).to eq("200")
    end
  end

  describe "update" do
    it "updates the user email, without sending email" do
      expect(bike.current_ownership).to be_present
      Sidekiq::Job.clear_all
      ActionMailer::Base.deliveries = []
      Sidekiq::Testing.inline! do
        expect {
          put "#{base_url}/#{bike.id}", params: {bike: {owner_email: "new@example.com", skip_email: "1"}}
        }.to change(Ownership, :count).by 1
      end
      expect(ActionMailer::Base.deliveries.count).to eq 0
      expect(flash[:success]).to be_present
      expect(response).to redirect_to(:edit_admin_bike)
      bike.reload
      expect(bike.current_ownership.owner_email).to eq "new@example.com"
      expect(bike.current_ownership.send_email).to be_falsey
    end
    context "with user deleted" do
      let(:user) { FactoryBot.create(:user) }
      let!(:bike) { FactoryBot.create(:bike, :with_ownership_claimed, user: user) }
      it "updates" do
        user.destroy
        bike.reload
        expect(bike.current_ownership).to be_present
        Sidekiq::Job.clear_all
        ActionMailer::Base.deliveries = []
        Sidekiq::Testing.inline! do
          expect {
            put "#{base_url}/#{bike.id}", params: {bike: {owner_email: "new@example.com", skip_email: "false"}}
          }.to change(Ownership, :count).by 1
        end
        expect(ActionMailer::Base.deliveries.count).to eq 1
        expect(flash[:success]).to be_present
        expect(response).to redirect_to(:edit_admin_bike)
        bike.reload
        expect(bike.current_ownership.owner_email).to eq "new@example.com"
        expect(bike.current_ownership.send_email).to be_truthy
      end
    end
    context "mark_recovered_reason" do
      let!(:bike) { FactoryBot.create(:stolen_bike) }
      let(:stolen_record) { bike.current_stolen_record }
      it "marks the bike recovered" do
        stolen_record.reload
        expect(stolen_record.recovered?).to be_falsey
        Sidekiq::Job.clear_all
        ActionMailer::Base.deliveries = []
        Sidekiq::Testing.inline! do
          patch "#{base_url}/#{bike.id}", params: {
            mark_recovered_reason: "some reason", mark_recovered_we_helped: "true", can_share_recovery: "1",
            bike: {owner_email: bike.owner_email}
          }
        end
        bike.reload
        expect(bike.status_stolen?).to be_falsey
        stolen_record.reload
        expect(stolen_record.recovered?).to be_truthy
        expect(stolen_record.recovered_description).to eq "some reason"
        expect(stolen_record.recovering_user_id).to eq current_user.id
        expect(stolen_record.index_helped_recovery).to be_truthy
        expect(stolen_record.can_share_recovery).to be_truthy
        expect(ActionMailer::Base.deliveries.count).to eq 0
      end
    end
    context "made without serial" do
      let(:bike) { FactoryBot.create(:bike, serial_number: "og serial") }
      it "makes it made without serial" do
        FactoryBot.create(:ownership, bike: bike)
        put "#{base_url}/#{bike.id}", params: {bike: {made_without_serial: "1", serial_number: "d"}}
        bike.reload
        expect(bike.made_without_serial?).to be_truthy
        expect(bike.serial_number).to eq("made_without_serial")
        expect(bike.normalized_serial_segments).to eq([])
      end
    end

    context "success" do
      let(:bike) { FactoryBot.create(:stolen_bike, :with_ownership) }
      let(:organization) { FactoryBot.create(:organization) }
      let(:bike_attributes) do
        {
          serial_number: "new thing and stuff",
          owner_email: "new@example.com",
          bike_organization_ids: ["", organization.id.to_s],
          made_without_serial: "0",
          stolen_records_attributes: {
            "0" => {
              street: "Cortland and Ashland",
              city: "Chicago"
            }
          }
        }
      end
      it "updates the bike and updates ownership and serial_normalizer" do
        expect_any_instance_of(SerialNormalizer).to receive(:save_segments)
        stolen_record = bike.fetch_current_stolen_record
        expect(stolen_record).to be_present
        expect(stolen_record.is_a?(StolenRecord)).to be_truthy
        current_ownership_id = bike.reload.current_ownership&.id
        expect(bike.updator_id).to be_nil

        put "#{base_url}/#{bike.id}", params: {bike: bike_attributes}
        expect(flash[:success]).to be_present
        expect(response).to redirect_to(:edit_admin_bike)
        expect(bike.reload.current_ownership_id).to_not eq current_ownership_id
        expect(bike.serial_number).to eq bike_attributes[:serial_number]
        expect(bike.fetch_current_stolen_record.id).to eq stolen_record.id
        expect(bike.owner_email).to eq "new@example.com"
        expect(bike.updated_by_user_at).to be_within(2).of Time.current
        expect(bike.updator_id).to eq current_user.id
        stolen_record.reload
        expect(stolen_record.street).to eq "Cortland and Ashland"
        expect(stolen_record.city).to eq "Chicago"
        expect(bike.bike_organization_ids).to eq([organization.id])
      end
    end
  end

  describe "unrecover" do
    let(:bike) { FactoryBot.create(:stolen_bike) }
    let(:stolen_record) { bike.current_stolen_record }
    let(:recovery_link_token) { stolen_record.find_or_create_recovery_link_token }
    let(:recovered_description) { "something cool and party and things and stuff and it came back!!! XOXO" }
    before do
      stolen_record.add_recovery_information(recovered_description: recovered_description)
      expect(bike.reload.status).to eq "status_with_owner"
    end

    it "marks unrecovered, without deleting the information about the recovery" do
      og_recover_link_token = recovery_link_token
      put "#{base_url}/unrecover?bike_id=#{bike.id}&stolen_record_id=#{stolen_record.id}"
      expect(flash[:success]).to match(/unrecovered/i)
      expect(response).to redirect_to admin_bike_path(bike)

      bike.reload
      expect(bike.status_stolen?).to be_truthy
      stolen_record.reload
      expect(stolen_record.recovered_description).to eq recovered_description
      expect(stolen_record.recovery_link_token).to_not eq og_recover_link_token
    end
    context "not matching stolen_record" do
      it "returns to bike page and renders flash" do
        put "#{base_url}/unrecover?bike_id=#{bike.id + 10}&stolen_record_id=#{stolen_record.id}"
        expect(flash[:error]).to match(/contact/i)
        expect(response).to redirect_to admin_bike_path(bike.id + 10)
        expect(bike.reload.status).to eq "status_with_owner"
      end
    end
  end

  describe "update_manufacturers" do
    it "updates the products" do
      bike1 = FactoryBot.create(:bike, manufacturer_other: "hahaha", model_audit_id: 12)
      bike2 = FactoryBot.create(:bike, manufacturer_other: "69", model_audit_id: 11, likely_spam: true)
      bike3 = FactoryBot.create(:bike, manufacturer_other: "69", model_audit_id: 12)
      manufacturer = FactoryBot.create(:manufacturer)
      Sidekiq::Job.clear_all
      post "#{base_url}/update_manufacturers", params: {
        manufacturer_id: manufacturer.id,
        bikes_selected: {bike1.id => bike1.id, bike2.id => bike2.id}
      }
      [bike1, bike2].each do |bike|
        bike.reload
        expect(bike.manufacturer).to eq manufacturer
        expect(bike.manufacturer_other).to be_nil
      end
      bike3.reload
      expect(bike3.manufacturer_other).to eq "69" # Sanity check
      expect(UpdateModelAuditJob.jobs.map { |j| j["args"] }.flatten).to match_array([11, 12])
    end
  end

  describe "destroy" do
    it "destroys the bike" do
      bike.current_ownership
      expect {
        delete "#{base_url}/#{bike.id}"
      }.to change(Bike, :count).by(-1)
      expect(response).to redirect_to(:admin_bikes)
      expect(flash[:success]).to match(/deleted/i)
      expect(CallbackJob::AfterBikeSaveJob).to have_enqueued_sidekiq_job(bike.id)
    end
    context "get_destroy" do
      it "destroys" do
        bike.current_ownership
        expect {
          get "#{base_url}/#{bike.id}/get_destroy"
        }.to change(Bike, :count).by(-1)
        expect(response).to redirect_to(:admin_bikes)
        expect(flash[:success]).to match(/deleted/i)
        expect(CallbackJob::AfterBikeSaveJob).to have_enqueued_sidekiq_job(bike.id)
      end
    end
    context "multi_destroy" do
      it "destroys the all", :flaky do
        bike1 = FactoryBot.create(:bike)
        bike2 = FactoryBot.create(:bike, example: true)
        bike3 = FactoryBot.create(:bike)
        expect(Bike.pluck(:id)).to eq([bike1.id, bike3.id])
        expect {
          get "#{base_url}/multi_delete/get_destroy", params: {
            id: "multi_destroy",
            bikes_selected: {bike1.id => bike1.id, bike2.id => bike2.id}
          }
        }.to change(Bike, :count).by(-1)
        expect(flash[:success]).to be_present
        expect(Bike.pluck(:id)).to eq([bike3.id])
        expect(Bike.unscoped.where.not(deleted_at: nil).pluck(:id)).to match_array([bike1.id, bike2.id])
      end
    end
  end
end
