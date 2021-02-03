require "rails_helper"

RSpec.describe BikesController, type: :request do
  include_context :request_spec_logged_in_as_user_if_present
  let(:base_url) { "/bikes" }
  let(:ownership) { FactoryBot.create(:ownership) }
  let(:current_user) { ownership.creator }
  let(:bike) { ownership.bike }

  describe "show" do
    context "example bike" do
      it "shows the bike" do
        ownership.bike.update_attributes(example: true)
        get "#{base_url}/#{bike.id}"
        expect(response).to render_template(:show)
        expect(assigns(:bike).id).to eq bike.id
        expect(assigns(:display_dev_info?)).to be_falsey
        expect(assigns(:claim_message)).to be_blank
      end
    end
    context "organization_id & sign_in_if_not" do
      let(:current_user) { nil }
      let(:organization) { FactoryBot.create(:organization) }
      it "redirects to sign in" do
        get "#{base_url}/#{bike.to_param}?organization_id=#{organization&.to_param}&sign_in_if_not=true"
        expect(response).to redirect_to new_session_path
        expect(flash[:notice]).to be_present
      end
      context "organization doesn't exist" do
        it "redirects to sign in" do
          get "#{base_url}/#{bike.to_param}?organization_id=not-an-actual-organization&sign_in_if_not=true"
          expect(response).to redirect_to new_session_path
          expect(flash[:notice]).to be_present
        end
      end
      context "organization passwordless users" do
        let!(:organization) { FactoryBot.create(:organization_with_organization_features, enabled_feature_slugs: ["passwordless_users"]) }
        it "redirects to magic link, because organization sign in" do
          get "#{base_url}/#{bike.to_param}?organization_id=#{organization&.to_param}&sign_in_if_not=1"
          expect(flash[:notice]).to be_present
          expect(response).to redirect_to(magic_link_session_path)
        end
      end
    end
    context "admin hidden (fake delete)" do
      before { ownership.bike.update_attributes(hidden: true) }
      it "404s" do
        expect {
          get "#{base_url}/#{bike.id}"
        }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end
    context "second ownership, from organization, with claim token" do
      let(:organization) { FactoryBot.create(:organization, :with_auto_user) }
      let(:bike) { FactoryBot.create(:bike_organized, organization: organization, owner_email: "new_user@stuff.com", creator: organization.auto_user) }
      let!(:ownership1) { FactoryBot.create(:ownership, bike: bike, creator: bike.creator) }
      let!(:ownership2) { FactoryBot.create(:ownership, bike: bike, creator: bike.creator, owner_email: bike.owner_email) }
      let(:current_user) { nil }
      it "renders claim_message" do
        ownership2.reload
        expect(ownership2.second?).to be_truthy
        expect(ownership2.current?).to be_truthy
        expect(ownership2.claimed?).to be_falsey
        expect(ownership2.claim_message).to eq "new_registration"
        get "#{base_url}/#{bike.id}?t=#{ownership2.token}"
        expect(response).to render_template(:show)
        expect(assigns(:bike).id).to eq bike.id
        expect(assigns(:claim_message)).to eq "new_registration"
      end
    end
    context "with creator logged in & claim token" do
      it "renders claim_message" do
        expect(bike.claimable_by?(current_user)).to be_falsey
        expect(current_user.authorized?(bike)).to be_truthy
        get "#{base_url}/#{bike.id}?t=#{ownership.token}"
        expect(response).to render_template(:show)
        expect(assigns(:bike).id).to eq bike.id
        expect(assigns(:claim_message)).to eq "new_registration"
      end
    end
    context "with user and claim token" do
      let!(:current_user) { FactoryBot.create(:user_confirmed, email: ownership.owner_email) }
      it "renders claim_message" do
        bike.reload
        expect(bike.current_ownership.claim_message).to eq "new_registration"
        expect(bike.current_ownership.claimed?).to be_falsey
        expect(bike.current_ownership.current?).to be_truthy
        expect(bike.claimable_by?(current_user)).to be_truthy
        get "#{base_url}/#{bike.id}?t=#{ownership.token}"
        expect(response).to render_template(:show)
        expect(assigns(:bike).id).to eq bike.id
        expect(assigns(:claim_message)).to eq "new_registration"
        bike.reload
        expect(bike.current_ownership.claimed?).to be_falsey
        expect(bike.current_ownership.current?).to be_truthy
      end
      context "ownership claimed" do
        let(:ownership) { FactoryBot.create(:ownership_claimed) }
        let(:current_user) { ownership.user }
        it "no claim_message" do
          bike.reload
          expect(bike.current_ownership.claimed).to be_truthy
          get "#{base_url}/#{bike.id}?t=#{ownership.token}"
          expect(response).to render_template(:show)
          expect(assigns(:bike).id).to eq bike.id
          expect(assigns(:claim_message)).to be_blank
        end
      end
    end
    context "organized user and bike" do
      let(:organization) { FactoryBot.create(:organization) }
      let(:organization2) { FactoryBot.create(:organization) }
      let(:ownership) { FactoryBot.create(:ownership_organization_bike, :claimed, organization: organization, can_edit_claimed: false) }
      let(:current_user) { FactoryBot.create(:organization_member, organization: organization) }
      let(:bike_sticker) { FactoryBot.create(:bike_sticker_claimed, bike: bike, organization: organization2) }
      it "includes passive organization, even when redirected from sticker from other org" do
        current_user.reload
        expect(current_user.organizations.count).to eq 1
        expect(current_user.authorized?(bike)).to be_falsey
        expect(current_user.authorized?(bike_sticker)).to be_falsey
        get "#{base_url}/#{bike.id}"
        expect(assigns(:bike).id).to eq bike.id
        expect(assigns(:passive_organization)&.id).to eq organization.id
        expect(assigns(:passive_organization_registered)).to be_truthy
        expect(assigns(:passive_organization_authorized)).to be_falsey
        expect(response).to render_template(:show)
        expect(response).to render_template("_organized_access_panel")
        # Scanning sticker should redirect to bike path
        get "#{base_url}/scanned/#{bike_sticker.code}/?organization_id=#{organization2.slug}"
        expect(response).to redirect_to(bike_path(bike, scanned_id: bike_sticker.code, organization_id: organization2.to_param))
        # ... test the response that is redirects
        get "#{base_url}/#{bike.to_param}?scanned_id=#{bike_sticker.code}&organization_id=#{organization2.to_param}"
        expect(assigns(:bike).id).to eq bike.id
        expect(assigns(:passive_organization)&.id).to eq organization.id
        expect(assigns(:passive_organization_registered)).to be_truthy
        expect(assigns(:passive_organization_authorized)).to be_falsey
        expect(response).to render_template(:show)
        expect(response).to render_template("_organized_access_panel")
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
        let(:current_user) { FactoryBot.create(:organization_admin, superuser: true) }
        let(:organization) { current_user.default_organization }
        let(:organization2) { FactoryBot.create(:organization) }
        it "responds with success" do
          current_user.reload
          expect(current_user.default_organization).to be_present
          expect(current_user.superuser?).to be_truthy
          get "#{base_url}/#{bike.id}"
          expect(response.status).to eq(200)
          expect(response).to render_template(:show)
          expect(assigns(:bike).id).to eq bike.id
          expect(flash).to_not be_present
          expect(assigns(:current_organization)&.id).to eq organization.id
          expect(session[:passive_organization_id]).to eq organization.id
          # Renders with current organization passed
          get "#{base_url}/#{bike.id}?organization_id=#{organization2.id}"
          expect(response).to render_template(:show)
          expect(flash).to_not be_present
          expect(assigns(:current_organization)&.id).to eq organization2.id
          expect(session[:passive_organization_id]).to eq organization2.id
          # Renders with no organization, if organization set to false
          get "#{base_url}/#{bike.id}?organization_id=false"
          expect(response).to render_template(:show)
          expect(flash).to_not be_present
          expect(assigns(:current_organization_force_blank)).to be_truthy
          expect(assigns(:current_organization)&.id).to be_blank
          expect(session[:passive_organization_id]).to eq "0"
        end
      end
      context "non-owner non-admin viewing" do
        let(:current_user) { FactoryBot.create(:user_confirmed) }
        it "404s" do
          expect {
            get "#{base_url}/#{bike.id}"
          }.to raise_error(ActiveRecord::RecordNotFound)
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
          expect {
            get "#{base_url}/#{bike.id}"
          }.to raise_error(ActiveRecord::RecordNotFound)
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
            expect(assigns(:passive_organization_registered)).to be_truthy
            expect(assigns(:passive_organization_authorized)).to be_truthy
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
        expect {
          get "#{base_url}/#{bike.id}"
        }.to raise_error(ActiveRecord::RecordNotFound)
      end
      context "with org member" do
        include_context :request_spec_logged_in_as_organization_member
        it "renders, even though user hidden" do
          expect(bike.user_hidden).to be_truthy
          expect(bike.owner).to_not eq current_user
          get "#{base_url}/#{bike.id}"
          expect(response.status).to eq(200)
          expect(assigns(:bike)).to eq bike
          expect(bike.created_by_parking_notification).to be_truthy
          get "#{base_url}/#{bike.id}/edit"
          expect(response.status).to eq(200)
          expect(assigns(:bike)).to eq bike
          expect(bike.created_by_parking_notification).to be_truthy
        end
      end
    end
    describe "graduated_notification_remaining param" do
      let(:graduated_notification) { FactoryBot.create(:graduated_notification_active) }
      let!(:bike) { graduated_notification.bike }
      let(:ownership) { bike.current_ownership }
      let(:organization) { graduated_notification.organization }
      let(:current_user) { nil }
      it "renders" do
        graduated_notification.reload
        bike.reload
        expect(graduated_notification.processed?).to be_truthy
        expect(graduated_notification.marked_remaining_link_token).to be_present
        expect(bike.graduated?(organization)).to be_truthy
        expect(bike.bike_organizations.pluck(:organization_id)).to eq([])
        get "#{base_url}/#{bike.id}?graduated_notification_remaining=#{graduated_notification.marked_remaining_link_token}"
        expect(assigns(:bike)).to eq bike
        expect(assigns(:token)).to eq graduated_notification.marked_remaining_link_token
        expect(assigns(:token_type)).to eq "graduated_notification"
        expect(assigns(:matching_notification)).to eq graduated_notification
        expect(flash).to be_blank
        bike.reload
        graduated_notification.reload
        expect(graduated_notification.marked_remaining?).to be_falsey
      end
      context "already marked recovered" do
        let(:graduated_notification) { FactoryBot.create(:graduated_notification, :marked_remaining) }
        it "renders" do
          expect(bike.graduated?(organization)).to be_falsey
          expect(bike.bike_organizations.pluck(:organization_id)).to eq([organization.id])
          get "#{base_url}/#{bike.id}?graduated_notification_remaining=#{graduated_notification.marked_remaining_link_token}"
          expect(assigns(:bike)).to eq bike
          expect(assigns(:token)).to eq graduated_notification.marked_remaining_link_token
          expect(assigns(:token_type)).to eq "graduated_notification"
          expect(assigns(:matching_notification)).to eq graduated_notification
          expect(flash).to be_blank
          bike.reload
          graduated_notification.reload
          expect(graduated_notification.marked_remaining?).to be_truthy
        end
      end
      context "unknown token" do
        it "renders" do
          expect(bike.graduated?(organization)).to be_truthy
          expect(bike.bike_organizations.pluck(:organization_id)).to eq([])
          get "#{base_url}/#{bike.id}?graduated_notification_remaining=333#{graduated_notification.marked_remaining_link_token}"
          expect(assigns(:bike)).to eq bike
          expect(assigns(:token)).to eq "333#{graduated_notification.marked_remaining_link_token}"
          expect(assigns(:token_type)).to eq "graduated_notification"
          expect(assigns(:matching_notification)).to be_blank
          expect(flash).to be_blank
          bike.reload
          graduated_notification.reload
          expect(bike.graduated?(organization)).to be_truthy
          expect(graduated_notification.status).to eq("active")
          expect(bike.bike_organizations.pluck(:organization_id)).to eq([])
        end
      end
      context "no token" do
        it "renders" do
          expect(bike.graduated?(organization)).to be_truthy
          expect(bike.bike_organizations.pluck(:organization_id)).to eq([])
          get "#{base_url}/#{bike.id}?graduated_notification_remaining="
          expect(assigns(:bike)).to eq bike
          expect(assigns(:token)).to be_blank
          expect(assigns(:token_type)).to be_blank
          expect(assigns(:matching_notification)).to be_blank
          expect(flash).to be_blank
          bike.reload
        end
      end
    end
    describe "parking_notification_retrieved param" do
      let!(:parking_notification) { FactoryBot.create(:parking_notification_organized, kind: "parked_incorrectly_notification", bike: bike, created_at: Time.current - 2.hours) }
      let(:creator) { parking_notification.user }
      it "renders" do
        parking_notification.reload
        expect(parking_notification.current?).to be_truthy
        expect(parking_notification.retrieval_link_token).to be_present
        expect(bike.current_parking_notification).to eq parking_notification
        get "#{base_url}/#{bike.id}?parking_notification_retrieved=#{parking_notification.retrieval_link_token}"
        expect(flash).to be_blank
        expect(assigns(:bike)).to eq bike
        expect(assigns(:token)).to eq parking_notification.retrieval_link_token
        expect(assigns(:token_type)).to eq "parked_incorrectly_notification"
        expect(assigns(:matching_notification)).to eq parking_notification
        expect(flash).to be_blank
        bike.reload
        parking_notification.reload
        expect(bike.current_parking_notification).to eq parking_notification
        expect(parking_notification.current?).to be_truthy
      end
      context "user not present" do
        let(:current_user) { nil }
        it "renders" do
          parking_notification.reload
          expect(parking_notification.current?).to be_truthy
          expect(parking_notification.retrieval_link_token).to be_present
          expect(parking_notification.retrieved?).to be_falsey
          expect(bike.current_parking_notification).to eq parking_notification
          get "#{base_url}/#{bike.id}?parking_notification_retrieved=#{parking_notification.retrieval_link_token}"
          expect(flash).to be_blank
          expect(assigns(:bike)).to eq bike
          expect(assigns(:token)).to eq parking_notification.retrieval_link_token
          expect(assigns(:token_type)).to eq "parked_incorrectly_notification"
          expect(assigns(:matching_notification)).to eq parking_notification
          parking_notification.reload
          expect(parking_notification.current?).to be_truthy
        end
      end
      context "with direct_link" do
        it "renders" do
          parking_notification.reload
          expect(parking_notification.current?).to be_truthy
          expect(parking_notification.retrieval_link_token).to be_present
          expect(bike.current_parking_notification).to eq parking_notification
          get "#{base_url}/#{bike.id}?parking_notification_retrieved=#{parking_notification.retrieval_link_token}&user_recovery=true"
          expect(flash).to be_blank
          expect(assigns(:bike)).to eq bike
          expect(assigns(:token)).to eq parking_notification.retrieval_link_token
          expect(assigns(:token_type)).to eq "parked_incorrectly_notification"
          expect(assigns(:matching_notification)).to eq parking_notification
          parking_notification.reload
          expect(parking_notification.current?).to be_truthy
        end
      end
      context "not notification token" do
        it "renders" do
          parking_notification.reload
          expect(parking_notification.current?).to be_truthy
          expect(parking_notification.retrieval_link_token).to be_present
          expect(parking_notification.retrieved?).to be_falsey
          expect(bike.current_parking_notification).to eq parking_notification
          get "#{base_url}/#{bike.id}?parking_notification_retrieved=#{parking_notification.retrieval_link_token}xxx"
          expect(flash).to be_blank
          expect(assigns(:bike)).to eq bike
          expect(assigns(:token)).to eq "#{parking_notification.retrieval_link_token}xxx"
          expect(assigns(:token_type)).to eq "parked_incorrectly_notification"
          expect(assigns(:matching_notification)).to be_blank
          expect(parking_notification.retrieved?).to be_falsey
        end
      end
      context "already retrieved" do
        let(:retrieval_time) { Time.current - 2.minutes }
        it "renders" do
          parking_notification.mark_retrieved!(retrieved_by_id: nil, retrieved_kind: "link_token_recovery", resolved_at: retrieval_time)
          parking_notification.reload
          expect(parking_notification.current?).to be_falsey
          expect(parking_notification.retrieval_link_token).to be_present
          expect(parking_notification.retrieved?).to be_truthy
          expect(bike.current_parking_notification).to be_blank
          get "#{base_url}/#{bike.id}?parking_notification_retrieved=#{parking_notification.retrieval_link_token}"
          expect(flash).to be_blank
          expect(assigns(:bike)).to eq bike
          expect(assigns(:token)).to eq parking_notification.retrieval_link_token
          expect(assigns(:token_type)).to eq "parked_incorrectly_notification"
          expect(assigns(:matching_notification)).to eq parking_notification
        end
      end
      context "abandoned as well" do
        let!(:parking_notification_abandoned) { parking_notification.retrieve_or_repeat_notification!(kind: "appears_abandoned_notification", user: creator) }
        it "renders" do
          ProcessParkingNotificationWorker.new.perform(parking_notification_abandoned.id)
          parking_notification.reload
          expect(parking_notification.current?).to be_falsey
          expect(parking_notification.active?).to be_truthy
          expect(parking_notification.resolved?).to be_falsey
          get "#{base_url}/#{bike.id}?parking_notification_retrieved=#{parking_notification_abandoned.retrieval_link_token}"
          expect(flash).to be_blank
          expect(assigns(:bike)).to eq bike
          expect(assigns(:token)).to eq parking_notification_abandoned.retrieval_link_token
          expect(assigns(:token_type)).to eq "appears_abandoned_notification"
          expect(assigns(:matching_notification)).to eq parking_notification_abandoned
        end
      end
      context "impound notification" do
        let!(:parking_notification_impounded) { parking_notification.retrieve_or_repeat_notification!(kind: "impound_notification", user: creator) }
        it "renders" do
          ProcessParkingNotificationWorker.new.perform(parking_notification_impounded.id)
          parking_notification.reload
          expect(parking_notification.current?).to be_falsey
          expect(parking_notification.resolved?).to be_truthy
          get "#{base_url}/#{bike.id}?parking_notification_retrieved=#{parking_notification.retrieval_link_token}"
          expect(flash).to be_blank
          expect(assigns(:bike)).to eq bike
          expect(assigns(:token)).to eq parking_notification.retrieval_link_token
          expect(assigns(:token_type)).to eq "parked_incorrectly_notification"
          expect(assigns(:matching_notification)).to eq parking_notification
        end
      end
    end
    context "with impound_record" do
      let(:impound_record) { FactoryBot.create(:impound_record, bike: bike) }
      it "includes an impound_claim" do
        expect(impound_record).to be_present
        expect(bike.reload.current_impound_record).to be_present
        get "#{base_url}/#{bike.id}"
        expect(flash).to be_blank
        expect(assigns(:bike)).to eq bike
        expect(assigns(:impound_claim)).to be_present
        expect(assigns(:impound_claim)&.id).to be_blank
      end
      context "current_user has impound_claim" do
        let!(:impound_claim) { FactoryBot.create(:impound_claim, user: current_user, impound_record: impound_record) }
        it "uses impound_claim" do
          expect(BikeDisplayer.display_impound_claim?(bike, current_user)).to be_truthy
          get "#{base_url}/#{bike.id}"
          expect(flash).to be_blank
          expect(assigns(:bike)).to eq bike
          expect(assigns(:impound_claim)&.id).to eq impound_claim.id
        end
      end
      context "current_user has submitting_impound_claim" do
        let!(:impound_claim) { FactoryBot.create(:impound_claim_with_stolen_record, bike: bike, user: current_user) }
        it "uses impound_claim" do
          bike.reload
          expect(bike.impound_claims_submitting.pluck(:id)).to eq([impound_claim.id])
          expect(BikeDisplayer.display_impound_claim?(bike, current_user)).to be_truthy
          get "#{base_url}/#{bike.id}"
          expect(flash).to be_blank
          expect(assigns(:bike)).to eq bike
          expect(assigns(:impound_claim)&.id).to eq impound_claim.id
        end
      end
    end
  end

  describe "new" do
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

  describe "create" do
    let(:current_user) { FactoryBot.create(:user_confirmed) }
    let(:manufacturer) { FactoryBot.create(:manufacturer) }
    let(:color) { FactoryBot.create(:color, name: "black") }
    let(:state) { FactoryBot.create(:state_illinois) }
    let(:country) { state.country }
    let(:testable_bike_params) { bike_params.except(:b_param_id_token, :embeded, :cycle_type_slug, :manufacturer_id) }
    let(:basic_bike_params) do
      {
        serial_number: "Bike serial",
        manufacturer_id: manufacturer.name,
        year: "2022",
        frame_model: "Cool frame model",
        primary_frame_color_id: color.id.to_s,
        owner_email: current_user.email
      }
    end
    let(:chicago_stolen_params) do
      {
        country_id: country.id,
        street: "2459 W Division St",
        city: "Chicago",
        zipcode: "60622",
        state_id: state.id
      }
    end
    context "unverified authenticity token" do
      include_context :test_csrf_token
      it "fails" do
        expect(current_user).to be_present
        expect {
          post base_url, params: {bike: basic_bike_params}
        }.to_not change(Ownership, :count)
        expect(flash[:error]).to match(/verify/i)
      end
    end
    context "blank serials" do
      let(:bike_params) { basic_bike_params.except(:year, :frame_model).merge(serial_number: "unknown", made_without_serial: "0") }
      it "creates" do
        expect(current_user.bikes.count).to eq 0
        expect {
          post base_url, params: {bike: bike_params}
        }.to change(Ownership, :count).by(1)
        expect(current_user.bikes.count).to eq 1
        new_bike = current_user.bikes.first
        expect(new_bike.claimed?).to be_truthy
        expect(new_bike.no_serial?).to be_truthy
        expect(new_bike.made_without_serial?).to be_falsey
        expect(new_bike.creation_state.origin).to eq "web"
        expect(new_bike.serial_unknown?).to be_truthy
        expect(new_bike.serial_number).to eq "unknown"
        expect(new_bike.normalized_serial_segments).to eq([])
      end
      context "made_without_serial" do
        it "creates, is made_without_serial" do
          expect(current_user.bikes.count).to eq 0
          expect {
            post base_url, params: {bike: bike_params.merge(made_without_serial: "1")}
          }.to change(Ownership, :count).by(1)
          expect(current_user.bikes.count).to eq 1
          new_bike = current_user.bikes.first
          expect(new_bike.claimed?).to be_truthy
          expect(new_bike.no_serial?).to be_truthy
          expect(new_bike.made_without_serial?).to be_truthy
          expect(new_bike.serial_unknown?).to be_falsey
          expect(new_bike.serial_number).to eq "made_without_serial"
          expect(new_bike.normalized_serial_segments).to eq([])
          expect(new_bike.current_ownership.impound_record_id).to be_blank
        end
      end
    end
    context "no existing b_param and stolen" do
      let(:wheel_size) { FactoryBot.create(:wheel_size) }
      let(:extra_long_string) { "Frame Material: Kona 6061 Aluminum Butted, Fork: Kona Project Two Aluminum Disc, Wheels: WTB ST i19 700c, Crankset: Shimano Sora, Drivetrain: Shimano Sora 9spd, Brakes: TRP Spyre C 160mm front / 160mm rear rotor, Seat Post: Kona Thumb w/Offset, Cockpit: Kona Road Bar/stem, Front Tire: WTB Riddler Comp 700x37c, Rear tire: WTB Riddler Comp 700x37c, Saddle: Kona Road" }
      let(:bike_params) do
        {
          b_param_id_token: "",
          cycle_type: "tall-bike",
          serial_number: "example serial",
          manufacturer_id: manufacturer.slug,
          manufacturer_other: "",
          year: "2016",
          frame_model: extra_long_string,
          primary_frame_color_id: color.id.to_s,
          secondary_frame_color_id: "",
          tertiary_frame_color_id: "",
          owner_email: "something@stuff.com",
          phone: "312.379.9513",
          date_stolen: Time.current.to_i
        }
      end
      before { expect(BParam.all.count).to eq 0 }
      context "successful creation" do
        include_context :geocoder_real
        it "creates a bike and doesn't create a b_param" do
          bike_user = FactoryBot.create(:user_confirmed, email: "something@stuff.com")
          VCR.use_cassette("bikes_controller-create-stolen-chicago", match_requests_on: [:path]) do
            bb_data = {bike: {rear_wheel_bsd: wheel_size.iso_bsd.to_s}, components: []}.as_json
            # We need to call clean_params on the BParam after bikebook update, so that
            # the foreign keys are assigned correctly. This is how we test that we're
            # This is also where we're testing bikebook assignment
            expect_any_instance_of(BikeBookIntegration).to receive(:get_model) { bb_data }
            expect {
              post base_url, params: {bike: bike_params, stolen_record: chicago_stolen_params.merge(show_address: true)}
            }.to change(Bike, :count).by(1)
            expect(flash[:success]).to be_present
            expect(BParam.all.count).to eq 0
            bike = Bike.last
            bike_params.except(:manufacturer_id, :phone, :date_stolen).each { |k, v| expect(bike.send(k).to_s).to eq v.to_s }
            expect(bike.manufacturer).to eq manufacturer
            expect(bike.status).to eq "status_stolen"
            bike_user.reload
            expect(bike.current_stolen_record.phone).to eq "3123799513"
            expect(bike_user.phone).to eq "3123799513"
            expect(bike.frame_model).to eq extra_long_string # People seem to like putting extra long strings into the frame_model field, so deal with it
            expect(bike.title_string.length).to be < 160 # Because the full frame_model makes things stupid
            stolen_record = bike.current_stolen_record
            chicago_stolen_params.except(:state_id).each { |k, v| expect(stolen_record.send(k).to_s).to eq v.to_s }
            expect(stolen_record.show_address).to be_truthy
          end
        end
      end
      context "failure" do
        it "assigns a bike and a stolen record with the attrs passed" do
          expect {
            post base_url, params: {bike: bike_params.except(:manufacturer_id), stolen_record: chicago_stolen_params}
          }.to change(Bike, :count).by(0)
          expect(BParam.all.count).to eq 1
          expect(BParam.last.bike_errors.to_s).to match(/manufacturer/i)
          bike = assigns(:bike)
          expect_attrs_to_match_hash(bike, bike_params.except(:manufacturer_id, :phone))
          expect(bike.status).to eq "status_stolen"
          # we retain the stolen record attrs, test that they are assigned correctly too
          expect_attrs_to_match_hash(bike.stolen_records.first, chicago_stolen_params)
        end
      end
    end
    context "no existing b_param, impounded" do
      let(:bike_params) { basic_bike_params }
      context "impound_record" do
        include_context :geocoder_real
        let(:impound_params) { chicago_stolen_params.merge(impounded_at: (Time.current - 1.day).utc, timezone: "UTC") }
        it "creates a new ownership and impound_record" do
          VCR.use_cassette("bikes_controller-create-impound-chicago", match_requests_on: [:path]) do
            expect {
              post base_url, params: {bike: bike_params, impound_record: impound_params}
              expect(assigns(:bike).errors&.full_messages).to_not be_present
            }.to change(Ownership, :count).by 1
            new_bike = Bike.last
            expect(new_bike).to be_present
            expect(new_bike.authorized?(current_user)).to be_truthy
            expect(new_bike.creation_state.origin).to eq "web"
            expect(new_bike.creation_state.organization&.id).to be_blank
            expect(new_bike.creation_state.creator&.id).to eq current_user.id
            expect(new_bike.status).to eq "status_impounded"
            expect(new_bike.status_humanized).to eq "found"
            expect_attrs_to_match_hash(new_bike, testable_bike_params)
            expect(ImpoundRecord.where(bike_id: new_bike.id).count).to eq 1
            impound_record = ImpoundRecord.where(bike_id: new_bike.id).first
            expect(new_bike.current_impound_record&.id).to eq impound_record.id
            expect(impound_record.kind).to eq "found"
            expect_attrs_to_match_hash(impound_record, impound_params.except(:impounded_at, :timezone))
            expect(impound_record.impounded_at.to_i).to be_within(1).of(Time.current.yesterday.to_i)

            ownership = new_bike.current_ownership
            expect(ownership.claimed?).to be_truthy
            expect(ownership.send_email?).to be_falsey
            expect(ownership.self_made?).to be_truthy
            expect(ownership.impound_record_id).to eq impound_record.id
          end
        end
        context "failure" do
          it "assigns a bike and a impound record with the attrs passed" do
            expect {
              post base_url, params: {bike: bike_params.except(:manufacturer_id), impound_record: impound_params}
            }.to change(Bike, :count).by(0)
            expect(BParam.all.count).to eq 1
            expect(BParam.last.bike_errors.to_s).to match(/manufacturer/i)
            bike = assigns(:bike)
            expect_attrs_to_match_hash(bike, bike_params.except(:manufacturer_id, :phone))
            expect(bike.status).to eq "status_impounded"
            # we retain the stolen record attrs, test that they are assigned correctly too
            expect_attrs_to_match_hash(bike.impound_records.first, impound_params.except(:impounded_at, :timezone))
          end
        end
      end
    end
    context "existing b_param, no bike" do
      let(:bike_params) do
        basic_bike_params.merge(cycle_type: "cargo-rear",
                                serial_number: "example serial",
                                secondary_frame_color_id: "",
                                tertiary_frame_color_id: "",
                                owner_email: "something@stuff.com")
      end
      let(:target_address) { {street: "278 Broadway", city: "New York", state: "NY", zipcode: "10007", country: "US", latitude: 40.7143528, longitude: -74.0059731} }
      let(:b_param) { BParam.create(params: {"bike" => bike_params.as_json}, origin: "embed_partial") }
      before do
        expect(b_param.partial_registration?).to be_truthy
        bb_data = {bike: {}}
        # We need to call clean_params on the BParam after bikebook update, so that
        # the foreign keys are assigned correctly.
        # This is also where we're testing bikebook assignment
        expect_any_instance_of(BikeBookIntegration).to receive(:get_model) { bb_data }
      end
      it "creates a bike" do
        expect {
          post base_url, params: {
            bike: {
              manufacturer_id: manufacturer.slug,
              b_param_id_token: b_param.id_token,
              address: default_location[:address],
              extra_registration_number: "XXXZZZ",
              organization_affiliation: "employee",
              phone: "888.777.6666"
            }
          }
        }.to change(Bike, :count).by(1)
        expect(flash[:success]).to be_present
        new_bike = Bike.last
        expect(new_bike.creator_id).to eq current_user.id
        b_param.reload
        expect(b_param.created_bike_id).to eq new_bike.id
        expect(b_param.phone).to eq "8887776666"
        expect_attrs_to_match_hash(new_bike, testable_bike_params)
        expect(new_bike.manufacturer).to eq manufacturer
        expect(new_bike.creation_state.origin).to eq "embed_partial"
        expect(new_bike.creation_state.creator).to eq new_bike.creator
        expect(new_bike.registration_address).to eq target_address.as_json
        expect(new_bike.extra_registration_number).to eq "XXXZZZ"
        expect(new_bike.organization_affiliation).to eq "employee"
        expect(new_bike.phone).to eq "8887776666"
        current_user.reload
        expect(new_bike.owner).to eq current_user # NOTE: not bike user
        expect(current_user.phone).to be_nil # Because the phone doesn't set for the creator
      end
      context "updated address" do
        let!(:target_address) { {street: "212 Main St", city: "Chicago", state: state.abbreviation, zipcode: "60647"} }
        it "creates the bike and does the updated address thing" do
          expect {
            post base_url, params: {
              bike: {
                manufacturer_id: manufacturer.slug,
                b_param_id_token: b_param.id_token,
                street: "212 Main St",
                city: "Chicago",
                state: "IL",
                zipcode: "60647",
                extra_registration_number: " ",
                organization_affiliation: "student",
                phone: "8887776666"
              }
            }
          }.to change(Bike, :count).by(1)
          expect(flash[:success]).to be_present
          new_bike = Bike.last
          b_param.reload
          expect(b_param.created_bike_id).to eq new_bike.id
          expect_attrs_to_match_hash(new_bike, testable_bike_params)
          expect(new_bike.manufacturer).to eq manufacturer
          expect(new_bike.creation_state.origin).to eq "embed_partial"
          expect(new_bike.creation_state.creator).to eq new_bike.creator
          expect(new_bike.registration_address).to eq target_address.as_json
          expect(new_bike.state.name).to eq "Illinois"
          expect(new_bike.extra_registration_number).to be_blank
          expect(new_bike.organization_affiliation).to eq "student"
          expect(new_bike.phone).to eq "8887776666"
          current_user.reload
          expect(new_bike.owner).to eq current_user # NOTE: not bike user
          expect(current_user.phone).to be_nil # Because the phone doesn't set for the creator
        end
        context "legacy address" do
          it "returns with address" do
            Country.united_states # Ensure it's around
            expect {
              post base_url, params: {
                bike: {
                  manufacturer_id: manufacturer.slug,
                  b_param_id_token: b_param.id_token,
                  address: "212 Main St",
                  address_city: "Chicago",
                  address_state: "IL",
                  address_zipcode: "60647",
                  extra_registration_number: " ",
                  organization_affiliation: "student",
                  phone: "8887776666"
                }
              }
            }.to change(Bike, :count).by(1)
            expect(flash[:success]).to be_present
            new_bike = Bike.last
            b_param.reload
            expect(b_param.address_hash.except("country")).to eq target_address.as_json
            expect(b_param.created_bike_id).to eq new_bike.id
            expect_attrs_to_match_hash(new_bike, testable_bike_params)
            expect(new_bike.manufacturer).to eq manufacturer
            expect(new_bike.creation_state.origin).to eq "embed_partial"
            expect(new_bike.creation_state.creator).to eq new_bike.creator
            expect(new_bike.registration_address).to eq target_address.as_json
            expect(new_bike.state.abbreviation).to eq "IL"
            expect(new_bike.extra_registration_number).to be_blank
            expect(new_bike.organization_affiliation).to eq "student"
            expect(new_bike.phone).to eq "8887776666"
            current_user.reload
            expect(new_bike.owner).to eq current_user # NOTE: not bike user
            expect(current_user.phone).to be_nil # Because the phone doesn't set for the creator
          end
        end
      end
    end
    context "existing b_param, created bike" do
      it "redirects to the bike" do
        b_param = BParam.create(params: {bike: {}}, created_bike_id: bike.id, creator_id: current_user.id)
        expect(b_param.created_bike).to be_present
        post base_url, params: {bike: {b_param_id_token: b_param.id_token}}
        expect(response).to redirect_to(edit_bike_url(bike.id))
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
          expect(parking_notification.retrieved_by).to eq current_user
          expect(parking_notification.resolved_at).to be_within(5).of Time.current
          expect(parking_notification.retrieved_kind).to eq "link_token_recovery"

          expect(parking_notification_abandoned.status).to eq "retrieved"
          expect(parking_notification_abandoned.retrieved_by).to be_blank
          expect(parking_notification_abandoned.associated_retrieved_notification).to eq parking_notification
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
    end
    context "stolen bike" do
      let(:bike) { FactoryBot.create(:stolen_bike, :with_ownership_claimed) }
      let(:ownership) { bike.current_ownership }
      it "renders" do
        get "#{base_url}/#{bike.id}/edit"
        expect(flash).to be_blank
        expect(response).to render_template(:edit_theft_details)
        expect(assigns(:bike).id).to eq bike.id
        bike.current_stolen_record.add_recovery_information
        # And if the bike is recovered, it redirects without page
        get "#{base_url}/#{bike.id}/edit?page=theft_details"
        expect(flash).to be_blank
        expect(response).to redirect_to(edit_bike_path(bike.id, page: "bike_details"))
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
        get "#{base_url}/#{bike.id}/edit?page=found_details"
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
            expect(bike.created_by_parking_notification).to be_falsey
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
        expect(bike.created_by_parking_notification).to be_truthy
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
        # NOTE: There is an issue with coordinate precision locally vs on CI. It isn't relevant, so bypassing
        expect(bike.latitude).to be_within(0.01).of(53.5183351)
        expect(bike.longitude).to be_within(0.01).of(-113.5015663)
        expect(bike.address_set_manually).to be_truthy
      end
    end
    context "mark bike stolen, the way it's done on the web" do
      include_context :geocoder_real # But it shouldn't make any actual calls!
      it "marks bike stolen and doesn't set a location in Kansas!" do
        bike.reload
        expect(bike.status_stolen?).to be_falsey
        expect(bike.claimed?).to be_falsey
        expect(bike.authorized?(current_user)).to be_truthy
        Sidekiq::Worker.clear_all
        Sidekiq::Testing.inline! do
          patch "#{base_url}/#{bike.id}", params: {
            edit_template: "report_stolen", bike: {date_stolen: Time.current.to_i}
          }
          expect(flash[:success]).to be_present
          # Redirects to same page passed
          expect(response).to redirect_to(edit_bike_path(bike.to_param, page: "report_stolen"))
          # ... and that page redirects to theft_details
          get edit_bike_path(bike.to_param, page: "report_stolen")
          expect(response).to redirect_to(edit_bike_path(bike.to_param, page: "theft_details"))
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
      end
      context "no sidekiq" do
        it "redirects correctly" do
          bike.reload
          patch "#{base_url}/#{bike.id}", params: {
            edit_template: "report_stolen", bike: {date_stolen: Time.current.to_i}
          }
          expect(flash[:success]).to be_present
          expect(assigns(:edit_templates)).to be_nil
          # Redirects to same page passed
          expect(response).to redirect_to(edit_bike_path(bike.to_param, page: "report_stolen"))
          # ... and that page redirects to theft_details
          get edit_bike_path(bike.to_param, page: "report_stolen")
          expect(response).to redirect_to(edit_bike_path(bike.to_param, page: "theft_details"))
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
          Sidekiq::Worker.clear_all
          Sidekiq::Testing.inline! do
            patch "#{base_url}/#{bike.id}", params: {
              edit_template: "report_stolen", bike: {date_stolen: time.to_i}
            }
            expect(flash[:success]).to be_present
            # Redirects to same page passed
            expect(response).to redirect_to(edit_bike_path(bike.to_param, page: "report_stolen"))
            # ... and that page redirects to theft_details
            get edit_bike_path(bike.to_param, page: "report_stolen")
            expect(response).to redirect_to(edit_bike_path(bike.to_param, page: "theft_details"))
          end
          bike.reload
          expect(bike.status).to eq "status_stolen"
          expect(bike.to_coordinates.compact).to eq([])
          expect(bike.user&.id).to eq current_user.id
          expect(bike.address_hash).to eq({country: "US", city: "New York", street: "278 Broadway", zipcode: "10007", state: nil, latitude: nil, longitude: nil}.as_json)

          stolen_record = bike.current_stolen_record
          expect(stolen_record).to be_present
          expect(stolen_record.to_coordinates.compact).to eq([])
          expect(stolen_record.date_stolen).to be_within(2).of time
          expect(stolen_record.phone).to eq "2221114444"
          expect(stolen_record.country_id).to eq Country.united_states.id
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
        expect(bike.created_by_parking_notification).to be_truthy
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
        expect(bike.created_by_parking_notification).to be_truthy
        expect(bike.stolen_records.count).to eq 0
        expect(bike.status).to eq "status_with_owner"
        expect(bike.user_hidden).to be_falsey
        expect(bike.editable_organizations.pluck(:id)).to eq([current_organization.id])
        expect(bike.authorized_by_organization?(org: current_organization)).to be_truthy # user is temporarily owner, so need to check org instead
        expect(bike.created_by_parking_notification).to be_truthy
      end
      context "add extra information" do
        let(:auto_user) { current_user }
        it "updates, doesn't change status" do
          bike.current_ownership.update(owner_email: current_user.email) # Can't figure out how to set this in the factory :(
          bike.reload
          expect(bike.claimed?).to be_falsey
          expect(bike.claimable_by?(current_user)).to be_truthy
          expect(bike.created_by_parking_notification).to be_truthy
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
          expect(bike.created_by_parking_notification).to be_truthy
          expect(bike.unregistered_parking_notification?).to be_truthy
          expect(bike.user_hidden).to be_truthy
          # And make sure it still can be rendered
          get "#{base_url}/#{bike.id}/edit"
          expect(response.status).to eq(200)
          expect(assigns(:bike)).to eq bike
          expect(bike.created_by_parking_notification).to be_truthy
          bike.reload
          expect(bike.claimed?).to be_truthy # Claimed by the edit render
          expect(bike.created_by_parking_notification).to be_truthy
          expect(bike.unregistered_parking_notification?).to be_truthy
        end
      end
    end
    context "adding location to a stolen bike" do
      let(:bike) { FactoryBot.create(:bike, stock_photo_url: "https://bikebook.s3.amazonaws.com/uploads/Fr/6058/13-brentwood-l-purple-1000.jpg") }
      let(:ownership) { FactoryBot.create(:ownership, bike: bike) }
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
        bike.reload
        stolen_record.current_alert_image
        stolen_record.reload
        expect(bike.current_stolen_record).to eq stolen_record
        expect(stolen_record.without_location?).to be_truthy
        og_alert_image_id = stolen_record.alert_image&.id # Fails without internet connection
        expect(og_alert_image_id).to be_present
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
        expect(stolen_record.show_address).to be_truthy
        expect(stolen_record.estimated_value).to eq 2101
        expect(stolen_record.locking_description).to eq "party"
        expect(stolen_record.lock_defeat_description).to eq "cool things"
        expect(stolen_record.theft_description).to eq "Something"
        expect(stolen_record.police_report_number).to eq "23891921"
        expect(stolen_record.police_report_department).to eq "Manahattan"
        expect(stolen_record.proof_of_ownership).to be_falsey
        expect(stolen_record.receive_notifications).to be_truthy

        expect(stolen_record.alert_image).to be_present
        expect(stolen_record.alert_image.id).to_not eq og_alert_image_id
      end
    end
    context "updating impound_record" do
      let!(:impound_record) { FactoryBot.create(:impound_record, user: current_user, bike: bike) }
      let(:state) { FactoryBot.create(:state, name: "New York", abbreviation: "NY", country: Country.united_states) }
      let(:impound_params) do
        {
          timezone: "America/Los_Angeles",
          impounded_at: "2020-04-28T11:00",
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
        expect(response).to redirect_to(edit_bike_path(bike, page: "found_details"))
        impound_record.reload
        expect(impound_record.latitude).to be_present
        expect(impound_record.impounded_at.to_i).to be_within(5).of 1588096800
        expect_attrs_to_match_hash(impound_record, impound_params.except(:timezone, :impounded_at))
      end
    end
  end
end
