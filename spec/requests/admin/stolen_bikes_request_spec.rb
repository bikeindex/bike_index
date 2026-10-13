require "rails_helper"

base_url = "/admin/stolen_bikes"
RSpec.describe Admin::StolenBikesController, type: :request do
  context "given a logged-in superuser" do
    include_context :request_spec_logged_in_as_superuser
    let(:bike) { FactoryBot.create(:stolen_bike, :with_ownership_claimed) }
    let!(:stolen_record) { bike.current_stolen_record }

    describe "index" do
      it "renders" do
        _bike = FactoryBot.create(:bike)
        stolen_record.update(police_report_department: "Oakland PD", police_report_number: "26-004512")
        get base_url
        expect(response.code).to eq("200")
        expect(response).to render_template("index")
        expect(flash).to_not be_present
        expect(assigns(:stolen_records)).to match_array([stolen_record])
        expect(response.body).to include("Contact owner", "Oakland PD", "26-004512")
        expect(Nokogiri::HTML(response.body).text.squish).to include("1 match", "showing 1–1 of 1")
        expect(response.body).to include('data-ui--table-column-order-storage-key-value="adminStolenBikesColumnsOrder"')
        expect(response.body).to include('name="photo_cell"', 'data-narrow-hidden="true"', 'data-controller="ui--table-overflow"')
        # test the search_with_promoted_alert because scoping is weird
        get "#{base_url}?search_with_promoted_alert=true"
        expect(response.code).to eq("200")
        expect(response).to render_template("index")
        expect(flash).to_not be_present
        expect(assigns(:stolen_records)).to match_array([])
      end

      context "with a period" do
        it "narrows by it" do
          stolen_record.update_column :created_at, 1.month.ago
          get base_url
          expect(assigns(:stolen_records)).to match_array([stolen_record])
          expect(response.body).to include("period=week")
          get "#{base_url}?period=week"
          expect(response.code).to eq("200")
          expect(assigns(:stolen_records)).to match_array([])
        end
      end

      context "with a duplicate" do
        let!(:duplicate_bike_group) { FactoryBot.create(:duplicate_bike_group, bike1: bike) }
        it "links to the duplicates" do
          get base_url
          expect(response.code).to eq("200")
          expect(response.body).to include("/admin/bikes/#{bike.id}?active_tab=duplicates")
        end
      end
    end

    describe "edit" do
      it "responds with 200 OK and renders the edit template" do
        expect(stolen_record.recovery_link_token).to_not be_present
        get "#{base_url}/#{bike.id}/edit"
        stolen_record.reload
        expect(assigns(:current_stolen_record)).to be_truthy
        expect(assigns(:stolen_record)).to eq stolen_record
        expect(stolen_record.recovery_link_token).to be_present
        expect(response.code).to eq("200")
        expect(response).to render_template("edit")
      end
      context "passed the stolen_record_id" do
        let!(:recovered_record) { FactoryBot.create(:stolen_record_recovered, bike: bike) }
        it "renders" do
          bike.reload
          expect(stolen_record.recovery_link_token).to_not be_present
          expect(bike.current_stolen_record).to eq stolen_record
          get "#{base_url}/#{recovered_record.id}/edit?stolen_record_id=1"
          expect(assigns(:stolen_record)).to eq recovered_record
          expect(assigns(:current_stolen_record)).to be_falsey
          expect(response.code).to eq("200")
          expect(response).to render_template("edit")
          expect(flash).to_not be_present
        end

        context "with a photo" do
          let!(:public_image) { FactoryBot.create(:public_image, imageable: bike) }
          it "returns from the photo edit to the stolen record" do
            get "#{base_url}/#{recovered_record.id}/edit?stolen_record_id=1"
            href = Nokogiri::HTML(response.body).at_css("a:contains('user edit')")["href"]
            expect(Rack::Utils.parse_query(URI(href).query)["return_to"]).to eq "/admin/stolen_bikes/#{recovered_record.id}/edit?stolen_record_id=1"
          end
        end
      end

      context "with no bike" do
        it "responds 404" do
          get "#{base_url}/#{bike.id + 1000}/edit"
          expect(response.code).to eq("404")
        end
      end
    end

    describe "approve" do
      it "updates the bike and stolen_record and enqueues the job" do
        bike.reload
        stolen_record.reload
        expect(stolen_record.approved).to be_falsey
        Sidekiq::Job.clear_all
        post "#{base_url}/#{bike.id}/approve"
        bike.reload
        stolen_record.reload
        expect(stolen_record.approved).to be_truthy
        expect(flash[:success]).to be_present
        expect(response).to redirect_to(:edit_admin_stolen_bike)
        expect(BikeJobs::ApproveStolenListingJob.jobs.count).to eq 1
        expect(BikeJobs::ApproveStolenListingJob.jobs.map { |j| j["args"] }.last.flatten).to eq([bike.id])
      end
      context "with a theft_alert" do
        let!(:alert_image) { FactoryBot.create(:alert_image, :with_image, stolen_record: stolen_record) }
        let(:theft_alert) { FactoryBot.create(:theft_alert_paid, stolen_record: stolen_record, user: bike.user) }
        it "updates the bike and stolen_record and enqueues the jobs" do
          expect(theft_alert.reload.bike_id).to eq bike.id
          expect(theft_alert.activateable?).to be_truthy
          expect(theft_alert.activateable_except_approval?).to be_truthy
          expect(theft_alert.start_at).to be_blank
          bike.reload
          stolen_record.reload
          expect(stolen_record.approved).to be_falsey
          Sidekiq::Job.clear_all
          post "#{base_url}/#{bike.id}/approve"
          bike.reload
          stolen_record.reload
          expect(stolen_record.approved).to be_truthy
          expect(flash[:success]).to be_present
          expect(response).to redirect_to(:edit_admin_stolen_bike)
          expect(BikeJobs::ApproveStolenListingJob.jobs.count).to eq 1
          expect(BikeJobs::ApproveStolenListingJob.jobs.map { |j| j["args"] }.last.flatten).to eq([bike.id])

          expect(CallbackJobs::AfterUserChangeJob.jobs.count).to eq 1
          CallbackJobs::AfterUserChangeJob.drain

          expect(BikeJobs::ActivateTheftAlertJob.jobs.count).to eq 1
          expect(BikeJobs::ActivateTheftAlertJob.jobs.map { |j| j["args"] }.last.flatten).to eq([theft_alert.id])
        end
      end
    end

    describe "bulk_update" do
      let(:stolen_record2) { FactoryBot.create(:stolen_record) }
      let!(:stolen_record3) { FactoryBot.create(:stolen_record) }
      let(:sr_selected) { {stolen_record.id => stolen_record.id, stolen_record2.id => stolen_record2.id} }

      it "approves them all" do
        expect(stolen_record.reload.approved).to be_falsey
        expect(stolen_record2.approved).to be_falsey
        Sidekiq::Job.clear_all
        post "#{base_url}/bulk_update", params: {sr_selected:, bulk_action: "approve"}
        expect(stolen_record.reload.approved).to be_truthy
        expect(stolen_record2.reload.approved).to be_truthy
        # Sanity check!
        expect(stolen_record3.reload.approved).to be_falsey
        expect(flash[:success]).to eq "2 stolen bikes approved"
        expect(BikeJobs::ApproveStolenListingJob.jobs.map { |j| j["args"] }.flatten).to match_array([bike.id, stolen_record2.bike_id])
      end

      it "marks the bikes spam" do
        post "#{base_url}/bulk_update", params: {sr_selected:, bulk_action: "spam"}
        expect(flash[:success]).to eq "2 stolen bikes marked spam"
        expect(Bike.unscoped.find(bike.id).likely_spam).to be_truthy
        expect(Bike.unscoped.find(stolen_record2.bike_id).likely_spam).to be_truthy
        expect(stolen_record3.bike.reload.likely_spam).to be_falsey
      end

      it "deletes the bikes" do
        post "#{base_url}/bulk_update", params: {sr_selected:, bulk_action: "delete"}
        expect(flash[:success]).to eq "2 stolen bikes deleted"
        expect(Bike.unscoped.find(bike.id).deleted_at).to be_present
        expect(Bike.unscoped.find(stolen_record2.bike_id).deleted_at).to be_present
        expect(stolen_record3.bike.reload.deleted_at).to be_blank
      end

      context "with sr_selected as an array" do
        it "approves them" do
          post "#{base_url}/bulk_update", params: {sr_selected: [stolen_record.id, stolen_record2.id], bulk_action: "approve"}
          expect(flash[:success]).to eq "2 stolen bikes approved"
          expect(stolen_record.reload.approved).to be_truthy
        end
      end

      context "nothing selected" do
        it "flashes an error" do
          post "#{base_url}/bulk_update", params: {bulk_action: "approve"}
          expect(flash[:error]).to be_present
        end
      end

      context "unknown action" do
        it "flashes an error" do
          post "#{base_url}/bulk_update", params: {sr_selected:, bulk_action: "destroy_all"}
          expect(flash[:error]).to be_present
          expect(stolen_record.reload.approved).to be_falsey
        end
      end
    end

    context "with only the stolen_bikes approve ability" do
      let(:current_user) { FactoryBot.create(:user_confirmed) }
      let!(:superuser_ability) { SuperuserAbility.create(user: current_user, controller_name: "stolen_bikes", action_name: "approve") }
      let(:sr_selected) { {stolen_record.id => stolen_record.id} }

      it "bulk approves, but doesn't delete" do
        post "#{base_url}/bulk_update", params: {sr_selected:, bulk_action: "approve"}
        expect(flash[:success]).to eq "1 stolen bike approved"
        expect(stolen_record.reload.approved).to be_truthy

        post "#{base_url}/bulk_update", params: {sr_selected:, bulk_action: "delete"}
        expect(flash[:error]).to match(/administrator/)
        expect(bike.reload.deleted_at).to be_blank
      end
    end

    describe "update" do
      let(:bike) { FactoryBot.create(:bike, :with_ownership_claimed) }
      let!(:stolen_record) { FactoryBot.create(:stolen_record, :with_images, bike:) }

      it "Doesn't update" do
        # This functionality was removed in PR #3029, because I don't know where there is a form that uses it
        # Now it just shows a flash error. If someone tells me about where it happens, I will fix!
        put "#{base_url}/#{bike.id}", params: {bike: {serial_number: "stuff"}}
        expect(response).to redirect_to(:edit_admin_stolen_bike)
        expect(flash[:error]).to be_present
      end
      context "without public image" do
        # Sometimes bikes have alert images even though they have no photo, this enables deleting it
        it "calls regenerates_alert_image" do
          expect(bike.reload.current_stolen_record_id).to eq stolen_record.id
          expect(stolen_record.reload.images_attached?).to be_truthy
          Sidekiq::Testing.inline! do
            put "#{base_url}/#{bike.id}", params: {public_image_id: nil, update_action: "regenerate_alert_image"}
          end
          expect(response).to redirect_to(:edit_admin_stolen_bike)
          expect(flash[:success]).to be_present
          expect(stolen_record.reload.images_attached?).to be_falsey
        end
      end
      context "with public image" do
        let!(:public_image) { FactoryBot.create(:public_image, :with_image_file, imageable: bike) }
        describe "regenerate_alert_image" do
          it "regenerates_alert_image" do
            expect(stolen_record.reload.images_attached?).to be_truthy
            expect(stolen_record.images_attached_id).to be_blank
            Sidekiq::Testing.inline! do
              put "#{base_url}/#{bike.id}", params: {public_image_id: public_image.id, update_action: "regenerate_alert_image"}
            end
            expect(response).to redirect_to(:edit_admin_stolen_bike)
            expect(flash[:success]).to be_present
            expect(stolen_record.reload.images_attached?).to be_truthy
            expect(stolen_record.images_attached_id).to eq public_image.id
          end
        end
        describe "delete image" do
          it "deletes image" do
            expect(bike.reload.current_stolen_record.images_attached?).to be_truthy
            expect(bike.public_images.count).to eq 1
            Sidekiq::Testing.inline! do
              put "#{base_url}/#{bike.id}", params: {public_image_id: public_image.id, update_action: "delete"}
            end
            expect(response).to redirect_to(:edit_admin_stolen_bike)
            expect(flash[:success]).to be_present
            expect(bike.reload.public_images.count).to eq 0
            expect(bike.current_stolen_record.images_attached?).to be_falsey
          end
        end
      end
    end
  end
end
