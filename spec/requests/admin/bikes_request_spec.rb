require "rails_helper"

RSpec.describe Admin::BikesController, type: :request do
  base_url = "/admin/bikes"
  let(:bike) { FactoryBot.create(:bike, :with_ownership) }

  context "given a logged-in superuser" do
    include_context :request_spec_logged_in_as_superuser
    describe "destroy" do
      it "destroys the bike" do
        bike.current_ownership
        expect {
          delete "#{base_url}/#{bike.id}"
        }.to change(Bike, :count).by(-1)
        expect(response).to redirect_to(:admin_bikes)
        expect(flash[:success]).to match(/deleted/i)
        expect(AfterBikeSaveWorker).to have_enqueued_sidekiq_job(bike.id)
      end
    end

    describe "update" do
      it "updates the user email, without sending email" do
        expect(bike.current_ownership).to be_present
        Sidekiq::Worker.clear_all
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
          Sidekiq::Worker.clear_all
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
          Sidekiq::Worker.clear_all
          ActionMailer::Base.deliveries = []
          Sidekiq::Testing.inline! do
            patch "#{base_url}/#{bike.id}", params: {
              mark_recovered_reason: "some reason", mark_recovered_we_helped: "true", can_share_recovery: "1",
              bike: { owner_email: bike.owner_email }
            }
          end
          bike.reload
          expect(bike.stolen).to be_falsey
          stolen_record.reload
          expect(stolen_record.recovered?).to be_truthy
          expect(stolen_record.recovered_description).to eq "some reason"
          expect(stolen_record.recovering_user_id).to eq current_user.id
          expect(stolen_record.index_helped_recovery).to be_truthy
          expect(stolen_record.can_share_recovery).to be_truthy
          expect(ActionMailer::Base.deliveries.count).to eq 0
        end
      end
    end
  end
end
