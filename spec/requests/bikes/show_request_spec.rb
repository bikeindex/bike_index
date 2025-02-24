require "rails_helper"

RSpec.describe "BikesController#show", type: :request do
  include_context :request_spec_logged_in_as_user_if_present
  let(:base_url) { "/bikes" }
  let(:ownership) { FactoryBot.create(:ownership) }
  let(:current_user) { ownership.creator }
  let(:bike) { ownership.bike }

  context "example bike" do
    it "shows the bike" do
      ownership.bike.update(example: true)
      get "#{base_url}/#{bike.id}"
      expect(response).to render_template(:show)
      expect(assigns(:bike).id).to eq bike.id
      expect(assigns(:display_dev_info?)).to be_falsey
      expect(assigns(:claim_message)).to be_blank
    end
  end
  context "likely_spam bike" do
    it "shows the bike" do
      ownership.bike.update(likely_spam: true)
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
  context "second ownership, from organization, with claim token" do
    let(:auto_user) { FactoryBot.create(:user_confirmed) }
    let(:organization) { FactoryBot.create(:organization, :with_auto_user, user: auto_user) }
    let(:bike) { FactoryBot.create(:bike_organized, creation_organization: organization, owner_email: auto_user.email, creator: auto_user) }
    let!(:ownership1) { bike.ownerships.first }
    let!(:ownership2) { FactoryBot.create(:ownership, bike: bike, creator: bike.creator, owner_email: "new_user@stuff.com") }
    let(:current_user) { nil }
    it "renders claim_message" do
      expect(ownership1.reload.organization_pre_registration?).to be_truthy
      expect(ownership2.reload.second?).to be_truthy
      expect(ownership2.current?).to be_truthy
      expect(ownership2.claimed?).to be_falsey
      expect(ownership2.new_registration?).to be_truthy
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
    let(:bike) { FactoryBot.create(:bike_organized, :with_ownership_claimed, creation_organization: organization, can_edit_claimed: false) }
    let(:current_user) { FactoryBot.create(:organization_user, organization: organization) }
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
  context "promoted_alert and recovery_link_token" do
    let(:promoted_alert) { FactoryBot.create(:promoted_alert_ended) }
    let(:stolen_record) { promoted_alert.stolen_record }
    let(:bike) { stolen_record.bike }
    let!(:image1) { FactoryBot.create(:public_image, filename: "bike-#{bike.id}.jpg", imageable: bike) }
    it "renders" do
      stolen_record.update_attribute :recovery_link_token, nil
      expect(stolen_record.reload.alert_image).to be_blank
      expect(stolen_record.recovery_link_token).to be_blank
      Sidekiq::Job.clear_all
      expect {
        get "#{base_url}/#{bike.id}"
        expect(assigns(:bike).id).to eq bike.id
        expect(response).to render_template(:show)
      }.to change(StolenBike::AfterStolenRecordSaveJob.jobs, :count).by 1
      expect(stolen_record.reload.alert_image).to be_blank
      expect {
        StolenBike::AfterStolenRecordSaveJob.new.perform(stolen_record.id)
      }.to change(StolenBike::AfterStolenRecordSaveJob.jobs, :count).by 0
      expect(stolen_record.reload.alert_image).to be_present
      expect(stolen_record.recovery_link_token).to be_present
    end
  end
  context "user hidden bike" do
    before { bike.update(marked_user_hidden: "true") }
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
      let!(:organization) { current_user.default_organization }
      let!(:organization2) { FactoryBot.create(:organization) }
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
    context "SuperuserAbility viewing" do
      let(:current_user) { FactoryBot.create(:user_confirmed) }
      let!(:superuser_ability) { FactoryBot.create(:superuser_ability, user: current_user, controller_name: "bikes", action_name: "edit") }
      it "responds with success" do
        current_user.reload
        expect(current_user.superuser?(controller_name: "bikes", action_name: "edit")).to be_truthy
        get "#{base_url}/#{bike.id}"
        expect(response.status).to eq(200)
        expect(response).to render_template(:show)
        expect(assigns(:bike).id).to eq bike.id
        expect(flash).to_not be_present
        expect(assigns(:current_organization)&.id).to be_blank
      end
    end
    context "non-owner non-admin viewing" do
      let(:current_user) { FactoryBot.create(:user_confirmed) }
      it "404s" do
        get "#{base_url}/#{bike.id}"
        expect(response.status).to eq 404
      end
    end
    context "organization viewing" do
      let(:can_edit_claimed) { false }
      let(:bike) do
        FactoryBot.create(:bike_organized,
          :with_ownership_claimed,
          creation_organization: organization,
          can_edit_claimed: can_edit_claimed,
          user: FactoryBot.create(:user))
      end
      let(:organization) { FactoryBot.create(:organization) }
      let(:current_user) { FactoryBot.create(:organization_user, organization: organization) }
      it "404s" do
        expect(bike.user).to_not eq current_user
        expect(bike.organizations.pluck(:id)).to eq([organization.id])
        expect(bike.visible_by?(current_user)).to be_falsey
        get "#{base_url}/#{bike.id}"
        expect(response.status).to eq 404
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
    let(:auto_user) { FactoryBot.create(:organization_user, organization: current_organization) }
    let(:parking_notification) do
      current_organization.update(auto_user: auto_user)
      FactoryBot.create(:parking_notification_unregistered, organization: current_organization, user: current_organization.auto_user)
    end
    let!(:bike) { parking_notification.bike }

    it "404s" do
      get "#{base_url}/#{bike.id}"
      expect(response.status).to eq 404
    end
    context "with org member" do
      include_context :request_spec_logged_in_as_organization_user
      it "renders, even though user hidden" do
        expect(bike.reload.user_hidden).to be_truthy
        expect(bike.owner).to_not eq current_user
        expect(bike.b_params.count).to eq 0
        expect(bike.status).to eq "unregistered_parking_notification"
        expect(bike.current_ownership).to be_present
        expect(bike.current_ownership.status).to eq "unregistered_parking_notification"
        expect(bike.current_ownership.origin).to eq "creator_unregistered_parking_notification"
        get "#{base_url}/#{bike.id}"
        expect(response.status).to eq(200)
        expect(assigns(:bike)).to eq bike
        get "#{base_url}/#{bike.id}/edit"
        expect(response.status).to eq(200)
        expect(assigns(:bike)).to eq bike
      end
    end
  end
  describe "graduated_notification_remaining param" do
    let(:graduated_notification) { FactoryBot.create(:graduated_notification_bike_graduated) }
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
        expect(graduated_notification.status).to eq("bike_graduated")
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
        expect(parking_notification.status).to eq "retrieved"
        expect(parking_notification.retrieval_link_token).to be_present
        expect(parking_notification.retrieved?).to be_truthy
        expect(bike.current_parking_notification).to be_blank
        get "#{base_url}/#{bike.id}?parking_notification_retrieved=#{parking_notification.retrieval_link_token}"
        expect(flash).to be_blank
        expect(assigns(:bike)).to eq bike
        expect(assigns(:token)).to eq parking_notification.retrieval_link_token
        expect(assigns(:token_type)).to eq "parked_incorrectly_notification"
        expect(assigns(:matching_notification)&.id).to eq parking_notification.id
      end
    end
    context "abandoned as well" do
      let!(:parking_notification_abandoned) { parking_notification.retrieve_or_repeat_notification!(kind: "appears_abandoned_notification", user: creator) }
      it "renders" do
        ProcessParkingNotificationJob.new.perform(parking_notification_abandoned.id)
        expect(parking_notification.reload.status).to eq "replaced"
        expect(parking_notification.active?).to be_truthy
        expect(parking_notification.resolved?).to be_falsey
        expect(parking_notification_abandoned.reload.status).to eq "current"
        get "#{base_url}/#{bike.id}?parking_notification_retrieved=#{parking_notification.retrieval_link_token}"
        expect(flash).to be_blank
        expect(assigns(:bike)).to eq bike
        expect(assigns(:token)).to eq parking_notification.retrieval_link_token
        expect(assigns(:matching_notification)&.id).to eq parking_notification.id
        # And then resolve that token, to test it works as well
        Sidekiq::Job.clear_all
        Sidekiq::Testing.inline! do
          put "#{base_url}/#{bike.id}/resolve_token?token=#{parking_notification.retrieval_link_token}&token_type=appears_abandoned_notification"
          expect(flash[:success]).to be_present
        end
        # parking_notification_abandoned was marked retrieved - even though the token was for parking_notification
        expect(parking_notification_abandoned.reload.status).to eq "retrieved"
        expect(parking_notification_abandoned.resolved?).to be_truthy
        expect(parking_notification_abandoned.retrieved_kind).to eq "link_token_recovery"
        expect(parking_notification.reload.status).to eq "replaced"
        expect(parking_notification.resolved?).to be_truthy
        expect(parking_notification.retrieved_kind).to be_blank
      end
    end
    context "impound notification" do
      let!(:parking_notification_impounded) { parking_notification.retrieve_or_repeat_notification!(kind: "impound_notification", user: creator) }
      it "renders" do
        ProcessParkingNotificationJob.new.perform(parking_notification_impounded.id)
        parking_notification.reload
        expect(parking_notification.current?).to be_falsey
        expect(parking_notification.resolved?).to be_truthy
        get "#{base_url}/#{bike.id}?parking_notification_retrieved=#{parking_notification.retrieval_link_token}"
        expect(flash).to be_blank
        expect(assigns(:bike)).to eq bike
        expect(assigns(:token)).to eq parking_notification.retrieval_link_token
        expect(assigns(:token_type)).to eq "parked_incorrectly_notification"
        expect(assigns(:matching_notification)&.id).to eq parking_notification.id
      end
    end
  end
  context "with impound_record" do
    let(:impound_record) { FactoryBot.create(:impound_record, bike: bike) }
    let(:current_user) { FactoryBot.create(:user_confirmed) }
    it "includes an impound_claim" do
      expect(impound_record).to be_present
      expect(bike.reload.current_impound_record).to be_present
      expect(bike.owner).to_not eq current_user
      get "#{base_url}/#{bike.id}"
      expect(flash).to be_blank
      expect(response).to be_ok
      expect(assigns(:bike)).to eq bike
      expect(assigns(:impound_claim)).to be_present
      expect(assigns(:impound_claim)&.id).to be_blank
      get "#{base_url}/#{bike.id}?contact_owner=true"
      expect(flash).to be_blank
      expect(response).to be_ok
      expect(assigns(:bike)).to eq bike
      expect(assigns(:contact_owner_open)).to be_truthy
    end
    context "current_user has impound_claim" do
      let!(:impound_claim) { FactoryBot.create(:impound_claim, user: current_user, impound_record: impound_record) }
      it "uses impound_claim" do
        expect(impound_record.creator_public_display_name).to eq "bike finder"
        expect(bike.reload.owner).to_not eq current_user
        expect(BikeDisplayer.display_impound_claim?(bike, current_user)).to be_truthy
        get "#{base_url}/#{bike.id}"
        expect(flash).to be_blank
        expect(assigns(:bike)).to eq bike
        expect(assigns(:impound_claim)&.id).to eq impound_claim.id
        expect(assigns(:contact_owner_open)).to be_falsey
      end
    end
    context "current_user has submitting_impound_claim" do
      let!(:impound_claim) { FactoryBot.create(:impound_claim_with_stolen_record, impound_record: impound_record, user: current_user) }
      it "uses impound_claim" do
        expect(impound_claim.reload.bike_claimed_id).to eq bike.id
        expect(impound_claim.bike_submitting_id).to_not eq bike.id
        expect(impound_claim.status).to eq "pending"
        bike.reload
        expect(bike.impound_claims_claimed.pluck(:id)).to eq([impound_claim.id])
        expect(BikeDisplayer.display_impound_claim?(bike, current_user)).to be_truthy
        get "#{base_url}/#{bike.id}"
        expect(flash).to be_blank
        expect(assigns(:bike)).to eq bike
        expect(assigns(:impound_claim)&.id).to eq impound_claim.id
        # It renders if submitting
        impound_claim.update(status: "submitting")
        expect(impound_claim.reload.status).to eq "submitting"
        expect(BikeDisplayer.display_impound_claim?(bike, current_user)).to be_truthy
        get "#{base_url}/#{bike.id}"
        expect(flash).to be_blank
        expect(assigns(:impound_claim)&.id).to eq impound_claim.id
        # It renders if approved
        impound_claim.update(status: "approved")
        expect(impound_claim.reload.status).to eq "approved"
        expect(BikeDisplayer.display_impound_claim?(bike, current_user)).to be_truthy
        get "#{base_url}/#{bike.id}"
        expect(flash).to be_blank
        expect(assigns(:impound_claim)&.id).to eq impound_claim.id

        impound_claim.update(status: "denied")
        expect(impound_claim.reload.status).to eq "denied"
        expect(BikeDisplayer.display_impound_claim?(bike, current_user)).to be_truthy
        get "#{base_url}/#{bike.id}"
        expect(flash).to be_blank
        expect(assigns(:impound_claim)&.id).to be_blank
        expect(assigns(:impound_claim)).to be_present # But it is rendered
      end
    end
  end
  context "qr code png" do
    it "renders" do
      get "#{base_url}/#{bike.id}.png"
      expect(response.status).to eq(200)
      # Previously, it was .gif
      get "#{base_url}/#{bike.id}.gif"
      expect(response).to redirect_to("#{base_url}/#{bike.id}.png")
    end
    describe "spokecard" do
      it "renders spokecard (which actually renders .png internally)" do
        get "#{base_url}/#{bike.id}/spokecard"
        expect(response.status).to eq(200)
        expect(response).to render_template(:spokecard)
      end
    end
  end
end
