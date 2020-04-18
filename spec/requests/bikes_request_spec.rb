require "rails_helper"

RSpec.describe BikesController, type: :request do
  let(:base_url) { "/bikes" }
  let(:ownership) { FactoryBot.create(:ownership) }
  let(:current_user) { ownership.creator }
  let(:bike) { ownership.bike }

  describe "show" do
    before { log_in(current_user) if current_user.present? }
    context "example bike" do
      it "shows the bike" do
        ownership.bike.update_attributes(example: true)
        get "#{base_url}/#{bike.id}"
        expect(response).to render_template(:show)
        expect(assigns(:bike).id).to eq bike.id
      end
    end
    context "admin hidden (fake delete)" do
      before { ownership.bike.update_attributes(hidden: true) }
      it "404s" do
        expect do
          get "#{base_url}/#{bike.id}"
        end.to raise_error(ActiveRecord::RecordNotFound)
      end
    end
    context "user hidden bike" do
      before { bike.update_attributes(marked_user_hidden: "true") }
      context "owner of bike viewing" do
        it "responds with success" do
          get "#{base_url}/#{bike.id}"
          expect(response.status).to eq(200)
          expect(response).to render_template(:show)
          expect(assigns(:bike).id).to eq bike.id
          expect(flash).to_not be_present
        end
      end
      context "Admin viewing" do
        let(:current_user) { FactoryBot.create(:admin) }
        it "responds with success" do
          get "#{base_url}/#{bike.id}"
          expect(response.status).to eq(200)
          expect(response).to render_template(:show)
          expect(assigns(:bike).id).to eq bike.id
          expect(flash).to_not be_present
        end
      end
      context "non-owner non-admin viewing" do
        let(:current_user) { FactoryBot.create(:user_confirmed) }
        it "404s" do
          expect do
            get "#{base_url}/#{bike.id}"
          end.to raise_error(ActiveRecord::RecordNotFound)
        end
      end
      context "organization viewing" do
        let(:can_edit_claimed) { false }
        let(:ownership) do
          FactoryBot.create(:ownership_organization_bike,
                            :claimed,
                            organization: organization,
                            can_edit_claimed: can_edit_claimed,
                            user: FactoryBot.create(:user))
        end
        let(:organization) { FactoryBot.create(:organization) }
        let(:current_user) { FactoryBot.create(:organization_member, organization: organization) }
        it "404s" do
          expect(bike.user).to_not eq current_user
          expect(bike.organizations.pluck(:id)).to eq([organization.id])
          expect(bike.visible_by?(current_user)).to be_falsey
          expect do
            get "#{base_url}/#{bike.id}"
          end.to raise_error(ActiveRecord::RecordNotFound)
        end
        context "bike organization editable" do
          let(:can_edit_claimed) { true }
          it "renders" do
            expect(bike.user).to_not eq current_user
            expect(bike.organizations.pluck(:id)).to eq([organization.id])
            expect(bike.visible_by?(current_user)).to be_truthy
            get "#{base_url}/#{bike.id}"
            expect(response.status).to eq(200)
            expect(response).to render_template(:show)
            expect(assigns(:bike).id).to eq bike.id
            expect(flash).to_not be_present
          end
        end
      end
    end
    context "unregistered_parking_notification (also user hidden)" do
      let(:current_organization) { FactoryBot.create(:organization) }
      let(:auto_user) { FactoryBot.create(:organization_member, organization: current_organization) }
      let(:parking_notification) do
        current_organization.update_attributes(auto_user: auto_user)
        FactoryBot.create(:unregistered_parking_notification, organization: current_organization, user: current_organization.auto_user)
      end
      let!(:bike) { parking_notification.bike }

      it "404s" do
        expect do
          get "#{base_url}/#{bike.id}"
        end.to raise_error(ActiveRecord::RecordNotFound)
      end
      context "with org member" do
        include_context :request_spec_logged_in_as_organization_member
        it "renders, even though user hidden" do
          expect(bike.user_hidden).to be_truthy
          expect(bike.owner).to_not eq current_user
          get "#{base_url}/#{bike.id}"
          expect(response.status).to eq(200)
          expect(assigns(:bike)).to eq bike
        end
      end
    end

    describe "parking_notification_retrieved param" do
      let!(:parking_notification) { FactoryBot.create(:parking_notification_organized, kind: "parked_incorrectly_notification", bike: bike, created_at: Time.current - 2.hours) }
      let(:creator) { parking_notification.user }
      it "retrieves the bike" do
        parking_notification.reload
        expect(parking_notification.current?).to be_truthy
        expect(parking_notification.retrieval_link_token).to be_present
        expect(bike.current_parking_notification).to eq parking_notification
        get "#{base_url}/#{bike.id}?parking_notification_retrieved=#{parking_notification.retrieval_link_token}"
        expect(response).to redirect_to(bike_path(bike.id))
        expect(assigns(:bike)).to eq bike
        expect(flash[:success]).to be_present
        bike.reload
        parking_notification.reload
        expect(bike.current_parking_notification).to be_blank
        expect(parking_notification.current?).to be_falsey
        expect(parking_notification.retrieved_by).to eq current_user
        expect(parking_notification.resolved_at).to be_within(5).of Time.current
        expect(parking_notification.retrieved_kind).to eq "link_token_recovery"
      end
      context "user not present" do
        let(:current_user) { nil }
        it "retrieves the bike" do
          parking_notification.reload
          expect(parking_notification.current?).to be_truthy
          expect(parking_notification.retrieval_link_token).to be_present
          expect(parking_notification.retrieved?).to be_falsey
          expect(bike.current_parking_notification).to eq parking_notification
          get "#{base_url}/#{bike.id}?parking_notification_retrieved=#{parking_notification.retrieval_link_token}"
          expect(response).to redirect_to(bike_path(bike.id))
          expect(assigns(:bike)).to eq bike
          expect(flash[:success]).to be_present
          bike.reload
          parking_notification.reload
          expect(bike.current_parking_notification).to be_blank
          expect(parking_notification.current?).to be_falsey
          expect(parking_notification.retrieved?).to be_truthy
          expect(parking_notification.retrieved_by).to be_blank
          expect(parking_notification.resolved_at).to be_within(5).of Time.current
          expect(parking_notification.retrieved_kind).to eq "link_token_recovery"
        end
      end
      context "with direct_link" do
        it "marks it retrieved directly" do
          parking_notification.reload
          expect(parking_notification.current?).to be_truthy
          expect(parking_notification.retrieval_link_token).to be_present
          expect(bike.current_parking_notification).to eq parking_notification
          get "#{base_url}/#{bike.id}?parking_notification_retrieved=#{parking_notification.retrieval_link_token}&user_recovery=true"
          expect(response).to redirect_to(bike_path(bike.id))
          expect(assigns(:bike)).to eq bike
          expect(flash[:success]).to be_present
          bike.reload
          parking_notification.reload
          expect(bike.current_parking_notification).to be_blank
          expect(parking_notification.current?).to be_falsey
          expect(parking_notification.retrieved_by).to eq current_user
          expect(parking_notification.resolved_at).to be_within(5).of Time.current
          expect(parking_notification.retrieved_kind).to eq "user_recovery"
        end
      end
      context "not notification token" do
        it "flash errors" do
          parking_notification.reload
          expect(parking_notification.current?).to be_truthy
          expect(parking_notification.retrieval_link_token).to be_present
          expect(parking_notification.retrieved?).to be_falsey
          expect(bike.current_parking_notification).to eq parking_notification
          get "#{base_url}/#{bike.id}?parking_notification_retrieved=#{parking_notification.retrieval_link_token}xxx"
          expect(response).to redirect_to(bike_path(bike.id))
          expect(assigns(:bike)).to eq bike
          expect(flash[:error]).to be_present
          parking_notification.reload
          expect(parking_notification.retrieved?).to be_falsey
        end
      end
      context "already retrieved" do
        let(:retrieval_time) { Time.current - 2.minutes }
        it "has a flash saying so" do
          parking_notification.mark_retrieved!(retrieved_by_id: nil, retrieved_kind: "link_token_recovery", resolved_at: retrieval_time)
          parking_notification.reload
          expect(parking_notification.current?).to be_falsey
          expect(parking_notification.retrieval_link_token).to be_present
          expect(parking_notification.retrieved?).to be_truthy
          expect(bike.current_parking_notification).to be_blank
          get "#{base_url}/#{bike.id}?parking_notification_retrieved=#{parking_notification.retrieval_link_token}"
          expect(response).to redirect_to(bike_path(bike.id))
          expect(assigns(:bike)).to eq bike
          expect(flash[:info]).to match(/retrieved/)
          parking_notification.reload
          expect(parking_notification.current?).to be_falsey
          expect(parking_notification.resolved_at).to be_within(1).of retrieval_time
        end
      end
      context "abandoned as well" do
        let!(:parking_notification_abandoned) { parking_notification.retrieve_or_repeat_notification!(kind: "appears_abandoned_notification", user: creator) }
        it "recovers both" do
          ProcessParkingNotificationWorker.new.perform(parking_notification_abandoned.id)
          parking_notification.reload
          expect(parking_notification.current?).to be_falsey
          expect(parking_notification.active?).to be_truthy
          expect(parking_notification.resolved?).to be_falsey
          Sidekiq::Worker.clear_all
          Sidekiq::Testing.inline! do
            get "#{base_url}/#{bike.id}?parking_notification_retrieved=#{parking_notification.retrieval_link_token}"
            expect(response).to redirect_to(bike_path(bike.id))
            expect(assigns(:bike)).to eq bike
            expect(flash[:success]).to be_present
          end
          bike.reload
          parking_notification.reload
          parking_notification_abandoned.reload
          expect(bike.current_parking_notification).to be_blank
          expect(parking_notification.current?).to be_falsey
          expect(parking_notification.retrieved?).to be_truthy
          expect(parking_notification.retrieved_by).to eq current_user
          expect(parking_notification.resolved_at).to be_within(5).of Time.current
          expect(parking_notification.retrieved_kind).to eq "link_token_recovery"

          expect(parking_notification_abandoned.retrieved?).to be_truthy
          expect(parking_notification_abandoned.retrieved_by).to be_blank
          expect(parking_notification_abandoned.associated_retrieved_notification).to eq parking_notification
        end
      end
      context "impound notification" do
        let!(:parking_notification_impounded) { parking_notification.retrieve_or_repeat_notification!(kind: "impound_notification", user: creator) }
        it "refuses" do
          ProcessParkingNotificationWorker.new.perform(parking_notification_impounded.id)
          parking_notification.reload
          expect(parking_notification.current?).to be_falsey
          expect(parking_notification.resolved?).to be_truthy
          Sidekiq::Worker.clear_all
          Sidekiq::Testing.inline! do
            get "#{base_url}/#{bike.id}?parking_notification_retrieved=#{parking_notification.retrieval_link_token}"
            expect(response).to redirect_to(bike_path(bike.id))
            expect(assigns(:bike)).to eq bike
            expect(flash[:error]).to match(/impound/i)
          end
          bike.reload
          parking_notification.reload
          expect(bike.current_parking_notification).to be_blank
          expect(parking_notification.retrieved?).to be_falsey
          expect(parking_notification.retrieved?).to be_falsey
        end
      end
    end
  end

  describe "update" do
    before { log_in(current_user) if current_user.present? }
    context "mark bike stolen, the way it's done in the app" do
      include_context :geocoder_real # But it shouldn't make any actual calls!
      it "marks bike stolen and doesn't set a location in Kansas!" do
        expect(current_user.authorized?(bike)).to be_truthy
        expect(bike.stolen?).to be_falsey
        Sidekiq::Worker.clear_all
        Sidekiq::Testing.inline! do
          patch "#{base_url}/#{bike.id}", params: { bike: { stolen: true } }
          expect(flash[:success]).to be_present
        end
        bike.reload
        expect(bike.stolen?).to be_truthy
        expect(bike.to_coordinates.compact).to eq([])

        stolen_record = bike.current_stolen_record
        expect(stolen_record).to be_present
        expect(stolen_record.to_coordinates.compact).to eq([])
        expect(stolen_record.date_stolen).to be_within(5).of Time.current
      end
      context "bike has coordinates" do
        it "marks the bike stolen, doesn't set a location, blanks bike location" do
          bike.update_attributes(country_id: Country.united_states, latitude: 40.7143528, longitude: -74.0059731)
          expect(current_user.authorized?(bike)).to be_truthy
          expect(bike.stolen?).to be_falsey
          Sidekiq::Worker.clear_all
          Sidekiq::Testing.inline! do
            patch "#{base_url}/#{bike.id}", params: { bike: { stolen: true } }
            expect(flash[:success]).to be_present
          end
          bike.reload
          expect(bike.stolen?).to be_truthy
          expect(bike.to_coordinates.compact).to eq([])

          stolen_record = bike.current_stolen_record
          expect(stolen_record).to be_present
          expect(stolen_record.to_coordinates.compact).to eq([])
          expect(stolen_record.date_stolen).to be_within(5).of Time.current
        end
      end
    end
  end
end
