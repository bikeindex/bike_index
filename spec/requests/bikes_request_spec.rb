require "rails_helper"

# Individual controller endpoints (methods) with a lot of tests are split out into separate request spec files
#  - bikes/create_request_spec.rb
#  - bikes/show_request_spec.rb
#  - bikes/update_request_spec.rb
#  - bikes/edit_request_spec.rb

RSpec.describe BikesController, type: :request do
  include_context :request_spec_logged_in_as_user_if_present
  let(:base_url) { "/bikes" }
  let(:ownership) { FactoryBot.create(:ownership) }
  let(:current_user) { ownership.creator }
  let(:bike) { ownership.bike }

  describe "index" do
    it "renders" do
      get base_url
      expect(response.code).to eq("200")
      expect(response).to render_template(:index)
    end
  end

  describe "new" do
    it "renders" do
      get "#{base_url}/new"
      expect(response.code).to eq("200")
      expect(assigns(:b_param).revised_new?).to be_truthy
      bike = assigns(:bike)
      expect(bike.status).to eq "status_with_owner"
      expect(bike.stolen_records.last).to be_blank
      expect(response).to render_template(:new)
      # This still wouldn't show address, because it doesn't have an organization with include_field_reg_address?
      expect(BikeDisplayer.display_edit_address_fields?(bike, current_user)).to be_truthy
    end
    context "stolen from params" do
      it "renders a new stolen bike" do
        get "#{base_url}/new?stolen=true"
        expect(response.code).to eq("200")
        expect(assigns(:b_param).revised_new?).to be_truthy
        bike = assigns(:bike)
        expect(bike.status).to eq "status_stolen"
        expect(bike.stolen_records.last).to be_present
        expect(bike.stolen_records.last.country_id).to eq Country.united_states.id
        expect(response).to render_template(:new)
        # Make sure it renders without address fields for a stolen bikes
        expect(BikeDisplayer.display_edit_address_fields?(bike, current_user)).to be_falsey
      end
      it "renders a new stolen bike from status" do
        country = FactoryBot.create(:country_canada)
        current_user.update(country_id: country.id)
        get "#{base_url}/new?status=stolen"
        expect(response.code).to eq("200")
        bike = assigns(:bike)
        expect(bike.status_humanized).to eq "stolen"
        expect(bike.stolen_records.last).to be_present
        expect(bike.stolen_records.last.country_id).to eq country.id
        expect(response).to render_template(:new)
      end
    end
    context "impounded from params" do
      it "renders with status" do
        get "#{base_url}/new?status=impounded"
        expect(response.code).to eq("200")
        bike = assigns(:bike)
        expect(bike.status).to eq "status_impounded"
        expect(bike.impound_records.last).to be_present
        expect(response).to render_template(:new)
      end
      it "found is impounded" do
        get "#{base_url}/new?status=found"
        expect(response.code).to eq("200")
        bike = assigns(:bike)
        expect(bike.status).to eq "status_impounded"
        expect(bike.impound_records.last).to be_present
        expect(response).to render_template(:new)
      end
    end
  end

  describe "resolve_token" do
    context "graduated_notification" do
      let(:graduated_notification) { FactoryBot.create(:graduated_notification_active) }
      let!(:bike) { graduated_notification.bike }
      let(:ownership) { bike.current_ownership }
      let(:organization) { graduated_notification.organization }
      let(:current_user) { nil }
      it "marks the bike remaining" do
        graduated_notification.reload
        bike.reload
        expect(graduated_notification.processed?).to be_truthy
        expect(graduated_notification.marked_remaining_link_token).to be_present
        expect(bike.graduated?(organization)).to be_truthy
        expect(bike.bike_organizations.pluck(:organization_id)).to eq([])
        put "#{base_url}/#{bike.id}/resolve_token?token=#{graduated_notification.marked_remaining_link_token}&token_type=graduated_notification"
        expect(response).to redirect_to(bike_path(bike.id))
        expect(flash[:success]).to be_present
        bike.reload
        graduated_notification.reload
        expect(bike.graduated?(organization)).to be_falsey
        expect(graduated_notification.marked_remaining?).to be_truthy
        expect(graduated_notification.marked_remaining_at).to be_within(2).of Time.current
        expect(bike.bike_organizations.pluck(:organization_id)).to eq([organization.id])
      end
      context "with associated_notifications" do
        let(:graduated_notification) { FactoryBot.create(:graduated_notification) } # so that it isn't processed prior to second creation
        let(:bike2) { FactoryBot.create(:bike_organized, :with_ownership, organization: organization, owner_email: bike.owner_email, created_at: bike.created_at + 1.hour) }
        let!(:graduated_notification2) { FactoryBot.create(:graduated_notification, bike: bike2, organization: organization) }
        it "marks both bikes remaining" do
          graduated_notification.process_notification
          graduated_notification.reload
          expect(graduated_notification.associated_bikes.pluck(:id)).to match_array([bike.id, bike2.id])
          expect(graduated_notification.associated_notifications.pluck(:id)).to eq([graduated_notification2.id])
          bike.reload
          expect(graduated_notification.processed?).to be_truthy
          expect(graduated_notification.marked_remaining_link_token).to be_present
          expect(bike.claimed?).to be_falsey # Test this works even with unclaimed bike
          expect(bike.graduated?(organization)).to be_truthy
          expect(bike.bike_organizations.pluck(:organization_id)).to eq([])
          graduated_notification2.reload
          bike2.reload
          expect(graduated_notification2.associated_bikes.pluck(:id)).to match_array([bike.id, bike2.id])
          expect(graduated_notification2.primary_notification_id).to eq graduated_notification.id
          expect(graduated_notification2.processed?).to be_truthy
          expect(graduated_notification2.marked_remaining_link_token).to be_present
          expect(bike2.user).to be_blank # Test this works even with unclaimed bike
          expect(bike2.graduated?(organization)).to be_truthy
          expect(bike2.bike_organizations.pluck(:organization_id)).to eq([])
          put "#{base_url}/#{bike.id}/resolve_token?token=#{graduated_notification.marked_remaining_link_token}&token_type=graduated_notification"
          expect(response).to redirect_to(bike_path(bike.id))
          expect(flash[:success]).to be_present
          bike.reload
          graduated_notification.reload
          expect(bike.graduated?(organization)).to be_falsey
          expect(graduated_notification.marked_remaining?).to be_truthy
          expect(graduated_notification.marked_remaining_at).to be_within(2).of Time.current
          expect(bike.bike_organizations.pluck(:organization_id)).to eq([organization.id])
          bike2.reload
          graduated_notification2.reload
          expect(bike2.graduated?(organization)).to be_falsey
          expect(graduated_notification2.marked_remaining?).to be_truthy
          expect(graduated_notification2.marked_remaining_at).to be_within(2).of Time.current
          expect(bike2.bike_organizations.pluck(:organization_id)).to eq([organization.id])
        end
      end
      context "already marked recovered" do
        let(:graduated_notification) { FactoryBot.create(:graduated_notification, :marked_remaining) }
        it "doesn't update, but flash success" do
          og_marked_remaining_at = graduated_notification.marked_remaining_at
          expect(og_marked_remaining_at).to be_present
          expect(bike.graduated?(organization)).to be_falsey
          expect(bike.bike_organizations.pluck(:organization_id)).to eq([organization.id])
          put "#{base_url}/#{bike.id}/resolve_token", params: {
            token: graduated_notification.marked_remaining_link_token,
            token_type: "graduated_notification"
          }
          expect(response).to redirect_to(bike_path(bike.id))
          expect(flash[:success]).to be_present
          bike.reload
          graduated_notification.reload
          expect(bike.graduated?(organization)).to be_falsey
          expect(graduated_notification.marked_remaining?).to be_truthy
          expect(graduated_notification.marked_remaining_at).to eq og_marked_remaining_at
          expect(bike.bike_organizations.pluck(:organization_id)).to eq([organization.id])
        end
      end
      context "unknown token" do
        it "flash errors" do
          expect(bike.graduated?(organization)).to be_truthy
          expect(bike.bike_organizations.pluck(:organization_id)).to eq([])
          put "#{base_url}/#{bike.id}/resolve_token?token=333#{graduated_notification.marked_remaining_link_token}&token_type=graduated_notification"
          expect(response).to redirect_to(bike_path(bike.id))
          expect(flash[:error]).to be_present
          bike.reload
          graduated_notification.reload
          expect(bike.graduated?(organization)).to be_truthy
          expect(graduated_notification.status).to eq("active")
          expect(bike.bike_organizations.pluck(:organization_id)).to eq([])
        end
      end
    end
    context "parking_notification" do
      let!(:parking_notification) { FactoryBot.create(:parking_notification_organized, kind: "parked_incorrectly_notification", bike: bike, created_at: Time.current - 2.hours) }
      let(:creator) { parking_notification.user }
      it "retrieves the bike" do
        parking_notification.reload
        expect(parking_notification.current?).to be_truthy
        expect(parking_notification.retrieval_link_token).to be_present
        expect(bike.current_parking_notification).to eq parking_notification
        put "#{base_url}/#{bike.id}/resolve_token?token=#{parking_notification.retrieval_link_token}&token_type=parked_incorrectly_notification"
        expect(response).to redirect_to(bike_path(bike.id))
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
          put "#{base_url}/#{bike.id}/resolve_token?token=#{parking_notification.retrieval_link_token}&token_type=parked_incorrectly_notification"
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
          put "#{base_url}/#{bike.id}/resolve_token?token=#{parking_notification.retrieval_link_token}&user_recovery=true&token_type=parked_incorrectly_notification"
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
          put "#{base_url}/#{bike.id}/resolve_token?token=#{parking_notification.retrieval_link_token}xxx&token_type=parked_incorrectly_notification"
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
          put "#{base_url}/#{bike.id}/resolve_token?token=#{parking_notification.retrieval_link_token}&token_type=parked_incorrectly_notification"
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
          expect(parking_notification_abandoned.reload.status).to eq "current"
          parking_notification.reload
          expect(parking_notification.status).to eq "replaced"
          expect(parking_notification.active?).to be_truthy
          expect(parking_notification.resolved?).to be_falsey
          Sidekiq::Worker.clear_all
          Sidekiq::Testing.inline! do
            put "#{base_url}/#{bike.id}/resolve_token?token=#{parking_notification.retrieval_link_token}&token_type=appears_abandoned_notification"
            expect(response).to redirect_to(bike_path(bike.id))
            expect(assigns(:bike)).to eq bike
            expect(flash[:success]).to be_present
          end
          bike.reload
          parking_notification.reload
          parking_notification_abandoned.reload
          expect(bike.current_parking_notification).to be_blank
          expect(parking_notification.status).to eq "replaced"
          expect(parking_notification.resolved_at).to be_within(5).of Time.current
          expect(parking_notification.retrieved_by&.id).to be_blank
          expect(parking_notification.retrieved_kind).to be_blank

          expect(parking_notification_abandoned.status).to eq "retrieved"
          expect(parking_notification_abandoned.retrieved_by&.id).to eq current_user.id
          expect(parking_notification_abandoned.retrieved_kind).to eq "link_token_recovery"
        end
      end
      context "impound notification" do
        let!(:parking_notification_impounded) { parking_notification.retrieve_or_repeat_notification!(kind: "impound_notification", user: creator) }
        it "refuses" do
          ProcessParkingNotificationWorker.new.perform(parking_notification_impounded.id)
          parking_notification.reload
          expect(parking_notification.status).to eq "replaced"
          expect(parking_notification.active?).to be_falsey
          expect(bike.reload.status).to eq "status_impounded"
          Sidekiq::Worker.clear_all
          Sidekiq::Testing.inline! do
            put "#{base_url}/#{bike.id}/resolve_token?token=#{parking_notification.retrieval_link_token}&token_type=parked_incorrectly_notification"
            expect(response).to redirect_to(bike_path(bike.id))
            expect(assigns(:bike)).to eq bike
            expect(flash[:error]).to match(/impound/i)
          end
          expect(bike.reload.status).to eq "status_impounded"
          parking_notification.reload
          expect(bike.current_parking_notification).to be_blank
          expect(parking_notification.retrieved?).to be_falsey
          expect(parking_notification.retrieved?).to be_falsey
        end
      end
    end
  end
end
