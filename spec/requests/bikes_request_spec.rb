require "rails_helper"

# Individual controller endpoints (methods) with a lot of tests are split out into separate request spec files
#  - bikes/create_request_spec.rb
#  - bikes/show_request_spec.rb

RSpec.describe BikesController, type: :request do
  include_context :request_spec_logged_in_as_user_if_present
  let(:base_url) { "/bikes" }
  let(:ownership) { FactoryBot.create(:ownership) }
  let(:current_user) { ownership.creator }
  let(:bike) { ownership.bike }

  describe "index" do
    context "stolen subdomain" do
      it "redirects to non-subdomain" do
        host! "stolen.bikeindex.org"
        get base_url
        expect(response).to redirect_to bikes_url(subdomain: false)
      end
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

  describe "edit" do
    let(:default_edit_templates) { %w[bike_details photos drivetrain accessories ownership groups remove report_stolen] }
    it "renders" do
      get "#{base_url}/#{bike.id}/edit"
      expect(flash).to be_blank
      expect(response).to render_template(:edit_bike_details)
      expect(assigns(:bike).id).to eq bike.id
      expect(assigns(:edit_templates).keys).to match_array(default_edit_templates)
      expect(bike.user_id).to_not eq current_user.id
      expect(BikeDisplayer.display_edit_address_fields?(bike, current_user)).to be_falsey
    end
    context "stolen bike" do
      let(:bike) { FactoryBot.create(:stolen_bike, :with_ownership_claimed) }
      let(:ownership) { bike.current_ownership }
      it "renders" do
        get "#{base_url}/#{bike.id}/edit"
        expect(flash).to be_blank
        expect(response).to render_template(:edit_theft_details)
        expect(assigns(:bike).id).to eq bike.id
        expect(bike.user_id).to eq current_user.id
        expect(BikeDisplayer.display_edit_address_fields?(bike, current_user)).to be_falsey
        bike.current_stolen_record.add_recovery_information
        # And if the bike is recovered, it redirects
        get "#{base_url}/#{bike.id}/edit?edit_template=theft_details"
        expect(flash).to be_blank
        expect(response).to redirect_to(edit_bike_path(bike.id, edit_template: "bike_details"))
        expect(bike.reload.user_id).to eq current_user.id
        expect(BikeDisplayer.display_edit_address_fields?(bike, current_user)).to be_truthy
      end
    end
    context "with impound_record" do
      let!(:impound_record) { FactoryBot.create(:impound_record, bike: bike) }
      it "renders" do
        target_edit_templates = default_edit_templates - ["report_stolen"] + ["found_details"]
        expect(bike.reload.status).to eq "status_impounded"
        expect(bike.owner&.id).to eq current_user.id
        expect(bike.authorized?(current_user)).to be_truthy
        get "#{base_url}/#{bike.id}/edit"
        expect(flash).to be_blank
        expect(response).to render_template(:edit_bike_details)
        expect(assigns(:edit_templates).keys).to match_array(target_edit_templates)
        # it also renders the found bike page
        get "#{base_url}/#{bike.id}/edit?edit_template=found_details"
        expect(flash).to be_blank
        expect(response).to render_template(:edit_found_details)
        expect(assigns(:edit_templates).keys).to match_array(target_edit_templates)
      end
      context "organized impound_record" do
        let!(:impound_record) { FactoryBot.create(:impound_record_with_organization, bike: bike) }
        before { ProcessImpoundUpdatesWorker.new.perform(impound_record.id) }
        it "redirects with flash error" do
          expect(bike.reload.status).to eq "status_impounded"
          get "#{base_url}/#{bike.id}/edit"
          expect(flash[:error]).to match(/impounded/i)
          expect(response).to redirect_to(bike_path(bike.id))
        end
        context "unclaimed" do
          let!(:bike) { FactoryBot.create(:bike, :with_ownership, user: nil, owner_email: "something@stuff.com") }
          let(:current_user) { FactoryBot.create(:user_confirmed, email: "something@stuff.com") }
          it "claims, but then redirects with flash error" do
            expect(current_user).to be_present # Doing weird lazy initialization here, so sanity check
            bike.reload
            expect(bike.current_ownership.claimed?).to be_falsey
            expect(bike.claimable_by?(current_user)).to be_truthy
            expect(bike.authorized?(current_user)).to be_falsey
            expect(bike.status).to eq "status_impounded"
            get "#{base_url}/#{bike.id}/edit"
            expect(flash[:error]).to match(/impounded/i)
            expect(response).to redirect_to(bike_path(bike.id))
            bike.reload
            expect(bike.current_ownership.claimed?).to be_truthy
            expect(bike.user.id).to eq current_user.id
            expect(bike.authorized?(current_user)).to be_falsey
          end
        end
        context "organization member" do
          let(:bike) { FactoryBot.create(:bike, :with_ownership_claimed) }
          let(:current_user) { FactoryBot.create(:organization_member, organization: impound_record.organization) }
          it "renders" do
            bike.reload
            expect(bike.claimed?).to be_truthy
            expect(bike.status).to eq "status_impounded"
            expect(bike.creator_unregistered_parking_notification?).to be_falsey
            expect(bike.bike_organizations.map(&:organization_id)).to eq([])
            expect(bike.authorized_by_organization?(u: current_user)).to be_truthy
            get "#{base_url}/#{bike.id}/edit"
            expect(flash).to be_blank
            expect(response).to render_template(:edit_bike_details)
            expect(assigns(:bike).id).to eq bike.id
            expect(response).to render_template(:edit_bike_details)
            expect(assigns(:edit_templates).keys).to match_array(default_edit_templates - ["report_stolen"])
          end
        end
      end
    end
    context "impounded unregistered_parking_notification by current_user" do
      let(:parking_notification) { FactoryBot.create(:unregistered_parking_notification, kind: "impound_notification") }
      let(:bike) { parking_notification.bike }
      let(:current_organization) { parking_notification.organization }
      let(:current_user) { parking_notification.user }
      let!(:ownership) { FactoryBot.create(:ownership_organization_bike, :claimed, bike: bike, user: current_user, organization: current_organization) }
      before { ProcessParkingNotificationWorker.new.perform(parking_notification.id) }
      it "renders" do
        parking_notification.reload
        impound_record = parking_notification.impound_record
        expect(impound_record).to be_present
        bike.reload
        expect(bike.current_impound_record&.id).to eq impound_record.id
        expect(bike.user).to eq current_user
        expect(bike.claimed?).to be_truthy
        expect(bike.creator_unregistered_parking_notification?).to be_truthy
        expect(bike.status).to eq "status_impounded"
        expect(bike.bike_organizations.map(&:organization_id)).to eq([current_organization.id])
        expect(bike.authorized?(current_user)).to be_truthy
        expect(bike.authorized_by_organization?(u: current_user)).to be_truthy # Because it's impounded
        get "#{base_url}/#{bike.id}/edit"
        expect(flash).to be_blank
        expect(response).to render_template(:edit_bike_details)
        expect(assigns(:bike).id).to eq bike.id
      end
    end
  end

  describe "update" do
    context "setting a bike_sticker" do
      it "gracefully fails if the number is weird" do
        expect(bike.bike_stickers.count).to eq 0
        patch "#{base_url}/#{bike.id}", params: {bike_sticker: "02891426438 "}
        expect(flash[:error]).to be_present
        bike.reload
        expect(bike.bike_stickers.count).to eq 0
      end
    end
    context "setting address for bike" do
      let(:current_user) { FactoryBot.create(:user_confirmed, default_location_registration_address) }
      let(:ownership) { FactoryBot.create(:ownership, creator: current_user, owner_email: current_user.email) }
      let(:update_attributes) { {street: "10544 82 Ave NW", zipcode: "AB T6E 2A4", city: "Edmonton", country_id: Country.canada.id, state_id: ""} }
      include_context :geocoder_real # But it shouldn't make any actual calls!
      it "sets the address for the bike" do
        expect(current_user.to_coordinates).to eq([default_location[:latitude], default_location[:longitude]])
        bike.update_attributes(updated_at: Time.current)
        bike.reload
        expect(bike.address_set_manually).to be_falsey
        expect(bike.owner).to eq current_user
        expect(bike.to_coordinates).to eq([default_location[:latitude], default_location[:longitude]])
        expect(current_user.authorized?(bike)).to be_truthy
        VCR.use_cassette("bike_request-set_manual_address") do
          Sidekiq::Worker.clear_all
          Sidekiq::Testing.inline! do
            patch "#{base_url}/#{bike.id}", params: {bike: update_attributes}
          end
        end
        bike.reload
        expect(bike.street).to eq "10544 82 Ave NW"
        expect(bike.country).to eq Country.canada
        expect(bike.address_set_manually).to be_truthy
        # NOTE: There is an issue with coordinate precision locally vs on CI. It isn't relevant, so bypassing
        expect(bike.latitude).to be_within(0.01).of(53.5183351)
        expect(bike.longitude).to be_within(0.01).of(-113.5015663)
      end
    end
    context "mark bike stolen, the way it's done on the web" do
      include_context :geocoder_real # But it shouldn't make any actual calls!
      it "marks bike stolen and doesn't set a location in Kansas!" do
        bike.reload
        expect(bike.status_stolen?).to be_falsey
        expect(bike.claimed?).to be_falsey
        expect(bike.authorized?(current_user)).to be_truthy
        AfterUserChangeWorker.new.perform(current_user.id)
        expect(current_user.reload.alert_slugs).to eq([])
        Sidekiq::Worker.clear_all
        Sidekiq::Testing.inline! do
          patch "#{base_url}/#{bike.id}", params: {
            edit_template: "report_stolen", bike: {date_stolen: Time.current.to_i}
          }
          expect(flash[:success]).to be_present
          # Redirects to theft_details
          expect(response).to redirect_to(edit_bike_path(bike.to_param, edit_template: "theft_details"))
        end
        bike.reload
        expect(bike.status).to eq "status_stolen"
        expect(bike.to_coordinates.compact).to eq([])
        expect(bike.claimed?).to be_falsey # Still controlled by creator

        stolen_record = bike.current_stolen_record
        expect(stolen_record).to be_present
        expect(stolen_record.to_coordinates.compact).to eq([])
        expect(stolen_record.date_stolen).to be_within(5).of Time.current
        expect(stolen_record.phone).to be_blank
        expect(stolen_record.country_id).to eq Country.united_states.id

        # No alert, because bike isn't claimed
        expect(current_user.reload.alert_slugs).to eq([])
      end
      context "no sidekiq" do
        it "redirects correctly" do
          bike.reload
          patch "#{base_url}/#{bike.id}", params: {
            edit_template: "report_stolen", bike: {date_stolen: Time.current.to_i}
          }
          expect(flash[:success]).to be_present
          expect(assigns(:edit_templates)).to be_nil
          # Redirects to theft_details
          expect(response).to redirect_to(edit_bike_path(bike.to_param, edit_template: "theft_details"))

          bike.reload
          expect(bike.status).to eq "status_stolen"
          expect(bike.to_coordinates.compact).to eq([])
          expect(bike.claimed?).to be_falsey # Still controlled by creator

          stolen_record = bike.current_stolen_record
          expect(stolen_record).to be_present
          expect(stolen_record.to_coordinates.compact).to eq([])
          expect(stolen_record.date_stolen).to be_within(5).of Time.current
          expect(stolen_record.phone).to be_blank
          expect(stolen_record.country_id).to eq Country.united_states.id
        end
      end
      context "bike has location" do
        let(:location_attrs) { {country_id: Country.united_states.id, city: "New York", street: "278 Broadway", zipcode: "10007", latitude: 40.7143528, longitude: -74.0059731, address_set_manually: true} }
        let(:time) { Time.current - 10.minutes }
        let(:phone) { "2221114444" }
        let(:current_user) { FactoryBot.create(:user_confirmed, phone: phone) }
        let(:ownership) { FactoryBot.create(:ownership, owner_email: current_user.email) }
        # If the phone isn't already confirmed, it sends a confirmation message
        let!(:user_phone_confirmed) { FactoryBot.create(:user_phone_confirmed, user: current_user, phone: phone) }
        it "marks the bike stolen, doesn't set a location, blanks bike location" do
          expect(current_user.reload.phone).to eq "2221114444"
          bike.update_attributes(location_attrs)
          bike.reload
          expect(bike.address_set_manually).to be_truthy
          expect(bike.status_stolen?).to be_falsey
          expect(bike.claimed?).to be_falsey
          expect(bike.user&.id).to eq current_user.id
          AfterUserChangeWorker.new.perform(current_user.id)
          expect(current_user.reload.alert_slugs).to eq([])
          Sidekiq::Worker.clear_all
          Sidekiq::Testing.inline! do
            # get edit because it should claim the bike
            get "#{base_url}/#{bike.id}/edit"
            expect(bike.reload.claimed?).to be_truthy
            patch "#{base_url}/#{bike.id}", params: {
              edit_template: "report_stolen", bike: {date_stolen: time.to_i}
            }
            expect(flash[:success]).to be_present
            # Redirects to theft_details
            expect(response).to redirect_to(edit_bike_path(bike.to_param, edit_template: "theft_details"))
          end
          bike.reload
          expect(bike.status).to eq "status_stolen"
          expect(bike.to_coordinates.compact).to eq([])
          expect(bike.user&.id).to eq current_user.id
          expect(bike.claimed?).to be_truthy
          expect(bike.owner&.id).to eq current_user.id
          expect(bike.address_hash).to eq({country: "US", city: "New York", street: "278 Broadway", zipcode: "10007", state: nil, latitude: nil, longitude: nil}.as_json)

          stolen_record = bike.current_stolen_record
          expect(stolen_record).to be_present
          expect(stolen_record.to_coordinates.compact).to eq([])
          expect(stolen_record.date_stolen).to be_within(2).of time
          expect(stolen_record.phone).to eq "2221114444"
          expect(stolen_record.country_id).to eq Country.united_states.id

          expect(current_user.reload.alert_slugs).to eq(["stolen_bike_without_location"])
        end
      end
    end
    context "unregistered_parking_notification email update" do
      let(:current_organization) { FactoryBot.create(:organization) }
      let(:auto_user) { FactoryBot.create(:organization_member, organization: current_organization) }
      let(:parking_notification) do
        current_organization.update_attributes(auto_user: auto_user)
        FactoryBot.create(:unregistered_parking_notification, organization: current_organization, user: current_organization.auto_user)
      end
      let!(:bike) { parking_notification.bike }
      let(:current_user) { FactoryBot.create(:organization_member, organization: current_organization) }
      it "updates email and marks not user hidden" do
        bike.reload
        expect(bike.claimed?).to be_falsey
        expect(bike.bike_organizations.first.can_not_edit_claimed).to be_falsey
        expect(bike.creator_unregistered_parking_notification?).to be_truthy
        expect(bike.unregistered_parking_notification?).to be_truthy
        expect(bike.user_hidden).to be_truthy
        expect(bike.authorized_by_organization?(u: current_user)).to be_truthy
        expect(bike.ownerships.count).to eq 1
        expect(bike.editable_organizations.pluck(:id)).to eq([current_organization.id])
        expect(bike.stolen_records.count).to eq 0
        Sidekiq::Worker.clear_all
        expect {
          patch "#{base_url}/#{bike.id}", params: {
            bike: {owner_email: "newuser@example.com"}
          }
          expect(flash[:success]).to be_present
        }.to change(Ownership, :count).by 1
        bike.reload
        expect(bike.claimed?).to be_falsey
        expect(bike.current_ownership.user_id).to be_blank
        expect(bike.current_ownership.owner_email).to eq "newuser@example.com"
        expect(bike.creator_unregistered_parking_notification?).to be_truthy
        expect(bike.stolen_records.count).to eq 0
        expect(bike.status).to eq "status_with_owner"
        expect(bike.user_hidden).to be_falsey
        expect(bike.editable_organizations.pluck(:id)).to eq([current_organization.id])
        expect(bike.authorized_by_organization?(org: current_organization)).to be_truthy # user is temporarily owner, so need to check org instead
        expect(bike.creator_unregistered_parking_notification?).to be_truthy
      end
      context "add extra information" do
        let(:auto_user) { current_user }
        it "updates, doesn't change status" do
          bike.current_ownership.update(owner_email: current_user.email) # Can't figure out how to set this in the factory :(
          bike.reload
          expect(bike.claimed?).to be_falsey
          expect(bike.claimable_by?(current_user)).to be_truthy
          expect(bike.creator_unregistered_parking_notification?).to be_truthy
          expect(bike.unregistered_parking_notification?).to be_truthy
          expect(bike.user_hidden).to be_truthy
          expect(bike.ownerships.count).to eq 1
          expect(bike.editable_organizations.pluck(:id)).to eq([current_organization.id])
          Sidekiq::Worker.clear_all
          expect {
            patch "#{base_url}/#{bike.id}", params: {bike: {description: "sooo cool and stuff"}}
            expect(flash[:success]).to be_present
          }.to_not change(Ownership, :count)
          bike.reload
          expect(bike.description).to eq "sooo cool and stuff"
          expect(bike.creator_unregistered_parking_notification?).to be_truthy
          expect(bike.unregistered_parking_notification?).to be_truthy
          expect(bike.user_hidden).to be_truthy
          # And make sure it still can be rendered
          get "#{base_url}/#{bike.id}/edit"
          expect(response.status).to eq(200)
          expect(assigns(:bike)).to eq bike
          expect(bike.creator_unregistered_parking_notification?).to be_truthy
          bike.reload
          expect(bike.claimed?).to be_truthy # Claimed by the edit render
          expect(bike.creator_unregistered_parking_notification?).to be_truthy
          expect(bike.unregistered_parking_notification?).to be_truthy
        end
      end
    end
    context "adding location to a stolen bike" do
      let(:bike) { FactoryBot.create(:bike, :with_ownership_claimed, stock_photo_url: "https://bikebook.s3.amazonaws.com/uploads/Fr/6058/13-brentwood-l-purple-1000.jpg", user: current_user) }
      let!(:stolen_record) { FactoryBot.create(:stolen_record, bike: bike) }
      let(:state) { FactoryBot.create(:state, name: "New York", abbreviation: "NY", country: Country.united_states) }
      let(:stolen_params) do
        {
          timezone: "America/Los_Angeles",
          date_stolen: "2020-04-28T11:00",
          phone: "111 111 1111",
          secondary_phone: "123 123 1234",
          country_id: Country.united_states.id,
          street: "278 Broadway",
          city: "New York",
          zipcode: "10007",
          state_id: state.id,
          show_address: "1",
          estimated_value: "2101",
          locking_description: "party",
          phone_for_users: "0",
          phone_for_shops: "1",
          phone_for_police: "0",
          lock_defeat_description: "cool things",
          theft_description: "Something",
          police_report_number: "23891921",
          police_report_department: "Manahattan",
          proof_of_ownership: "0",
          receive_notifications: "1",
          id: stolen_record.id
        }
      end

      it "clears the existing alert image" do
        # Cassette required for alert image
        VCR.use_cassette("bike_request-stolen", match_requests_on: [:method], re_record_interval: 1.month) do
          expect(bike.reload.claimed?).to be_truthy
          expect(bike.owner&.id).to eq current_user.id
          stolen_record.current_alert_image
          stolen_record.reload
          expect(bike.current_stolen_record).to eq stolen_record
          expect(stolen_record.without_location?).to be_truthy
          og_alert_image_id = stolen_record.alert_image&.id # Fails without internet connection
          expect(og_alert_image_id).to be_present
          # Test stolen record phoning
          expect(stolen_record.phone_for_everyone).to be_falsey
          expect(stolen_record.phone_for_users).to be_truthy
          expect(stolen_record.phone_for_shops).to be_truthy
          expect(stolen_record.phone_for_police).to be_truthy
          AfterUserChangeWorker.new.perform(current_user.id)
          expect(current_user.reload.alert_slugs).to eq(["stolen_bike_without_location"])
          current_user.update_column :updated_at, Time.current - 5.minutes
          Sidekiq::Worker.clear_all
          Sidekiq::Testing.inline! do
            patch "#{base_url}/#{bike.id}", params: {
              bike: {stolen: "true", stolen_records_attributes: {"0" => stolen_params}}
            }
            expect(flash[:success]).to be_present
          end
          bike.reload
          stolen_record.reload
          stolen_record.current_alert_image
          stolen_record.reload

          expect(bike.current_stolen_record.id).to eq stolen_record.id
          expect(stolen_record.to_coordinates.compact).to eq([default_location[:latitude], default_location[:longitude]])
          expect(stolen_record.date_stolen).to be_within(5).of Time.at(1588096800)

          expect(stolen_record.phone).to eq "1111111111"
          expect(stolen_record.secondary_phone).to eq "1231231234"
          expect(stolen_record.country_id).to eq Country.united_states.id
          expect(stolen_record.state_id).to eq state.id
          expect(stolen_record.show_address).to be_falsey
          expect(stolen_record.estimated_value).to eq 2101
          expect(stolen_record.locking_description).to eq "party"
          expect(stolen_record.lock_defeat_description).to eq "cool things"
          expect(stolen_record.theft_description).to eq "Something"
          expect(stolen_record.police_report_number).to eq "23891921"
          expect(stolen_record.police_report_department).to eq "Manahattan"
          expect(stolen_record.proof_of_ownership).to be_falsey
          expect(stolen_record.receive_notifications).to be_truthy
          expect(stolen_record.phone_for_everyone).to be_falsey
          expect(stolen_record.phone_for_users).to be_falsey
          expect(stolen_record.phone_for_shops).to be_truthy
          expect(stolen_record.phone_for_police).to be_falsey

          expect(stolen_record.alert_image).to be_present
          expect(stolen_record.alert_image.id).to_not eq og_alert_image_id
        end

        expect(current_user.reload.alert_slugs).to eq([])
        # Test that we're bumping user, to bust cache
        expect(current_user.updated_at).to be > Time.current - 5
      end
    end
    context "updating impound_record" do
      let!(:impound_record) { FactoryBot.create(:impound_record, user: current_user, bike: bike) }
      let(:state) { FactoryBot.create(:state, name: "New York", abbreviation: "NY", country: Country.united_states) }
      let(:impound_params) do
        {
          timezone: "America/Los_Angeles",
          impounded_at_with_timezone: "2020-04-28T11:00",
          country_id: Country.united_states.id,
          street: "278 Broadway",
          city: "New York",
          zipcode: "10007",
          state_id: state.id
        }
      end
      it "updates the impound_record" do
        bike.reload
        expect(bike.current_impound_record_id).to eq impound_record.id
        expect(bike.authorized?(current_user)).to be_truthy
        impound_record.reload
        expect(impound_record.latitude).to be_blank
        patch "#{base_url}/#{bike.id}", params: {
          bike: {impound_records_attributes: {"0" => impound_params}},
          edit_template: "found_details"
        }
        expect(flash[:success]).to be_present
        expect(response).to redirect_to(edit_bike_path(bike, edit_template: "found_details"))
        impound_record.reload
        expect(impound_record.latitude).to be_present
        expect(impound_record.impounded_at.to_i).to be_within(5).of 1588096800
        expect_attrs_to_match_hash(impound_record, impound_params.except(:impounded_at_with_timezone, :timezone))
      end
    end
  end
end
