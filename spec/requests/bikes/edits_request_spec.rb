require "rails_helper"

RSpec.describe Bikes::EditsController, type: :request do
  include_context :request_spec_logged_in_as_user_if_present
  let(:base_url) { "/bikes/#{bike.to_param}/edit" }
  let(:bike) { FactoryBot.create(:bike, :with_ownership_claimed) }
  let(:current_user) { bike.creator }

  let(:edit_templates) do
    {
      bike_details: "Details",
      photos: "Photos",
      drivetrain: "Wheels and Drivetrain",
      accessories: "Accessories and Components",
      ownership: "Transfer Ownership",
      groups: "Groups and Organizations",
      remove: "Hide or Delete",
      report_stolen: "Report Stolen or Missing"
    }
  end
  let(:theft_templates) do
    {
      theft_details: "Theft details",
      publicize: "Share on Social Media",
      alert: "Activate Promoted Alert",
      report_recovered: "Mark this Bike Recovered"
    }
  end
  let(:theft_edit_templates) { edit_templates.except(:report_stolen).merge(theft_templates) }

  context "no current_user" do
    let(:current_user) { nil }
    it "redirects and sets the flash" do
      get base_url
      expect(response).to redirect_to bike_path(bike)
      expect(flash[:error]).to be_present
      expect(session[:return_to]).to eq(edit_bike_path(bike))
    end
  end
  context "current_user not owner" do
    let(:current_user) { FactoryBot.create(:user_confirmed) }
    it "redirects and sets the flash" do
      expect(bike.authorized?(current_user)).to be_falsey
      get base_url
      expect(response).to redirect_to bike_path(bike)
      expect(flash[:error]).to be_present
      expect(session[:return_to]).to be_blank
      # Because user is not bike#user
      expect(BikeDisplayer.display_edit_address_fields?(bike, current_user)).to be_falsey
    end
    context "current_user present but hasn't claimed the bike" do
      let(:bike) { FactoryBot.create(:bike, :with_ownership, user: current_user) }
      it "claims and renders" do
        expect(bike.ownerships.count).to eq 1
        expect(bike.claimed?).to be_falsey
        expect(bike.claimable_by?(current_user)).to be_truthy
        get base_url
        bike.reload
        expect(bike.claimed?).to be_truthy
        expect(bike.user_id).to eq current_user.id
        expect(response).to be_ok
        expect(assigns(:edit_template)).to eq "bike_details"
        expect(session[:return_to]).to be_blank
      end
    end
  end
  context "not-creator but member of creation_organization" do
    let(:bike) { FactoryBot.create(:bike_organized) }
    let(:organization) { bike.creation_organization }
    let(:current_user) { FactoryBot.create(:organization_user, organization: organization) }
    it "renders" do
      expect(bike.user_id).to_not eq current_user.id
      expect(bike.creation_organization&.id).to eq current_user.organizations.first.id
      get base_url
      expect(response).to be_ok
      expect(assigns(:edit_template)).to eq "bike_details"
      expect(session[:return_to]).to be_blank
    end
  end

  it "renders" do
    get base_url
    expect(flash).to be_blank
    expect(response).to render_template(:bike_details)
    expect(assigns(:bike).id).to eq bike.id
    expect(assigns(:edit_templates)).to match_hash_indifferently edit_templates
    # Because user is bike#user
    expect(BikeDisplayer.display_edit_address_fields?(bike, current_user)).to be_truthy
    # If passed an unknown template, it renders default template
    get base_url, params: {id: bike.id, edit_template: "root_party"}
    expect(response).to redirect_to(edit_bike_url(bike, edit_template: :bike_details))
  end
  context "with bike_versions" do
    it "renders" do
      Flipper.enable :bike_versions # Simpler to just enable it all
      get base_url
      expect(response.status).to eq 200
      expect(response).to render_template(:bike_details)
      expect(assigns(:edit_templates)).to eq edit_templates.merge(versions: "Versions").as_json
      get "#{base_url}/versions"
      expect(response.status).to eq 200
      expect(response).to render_template(:versions)
    end
  end
  context "with owner_email" do
    it "renders with owner_email in ownership" do
      get "#{base_url}?owner_email=new_email@stuff.com"
      expect(response.status).to eq 200
      expect(response).to render_template(:bike_details)
      expect(assigns(:new_email_assigned)).to be_blank
      expect(assigns(:bike).owner_email).to eq bike.owner_email
      get "#{base_url}/ownership?owner_email=new_email@stuff.com"
      expect(response.status).to eq 200
      expect(response).to render_template(:ownership)
      expect(assigns(:bike).owner_email).to eq "new_email@stuff.com"
      expect(assigns(:new_email_assigned)).to be_truthy
      expect {
        put "/bikes/#{bike.to_param}", params: {bike: {owner_email: "new_email@stuff.com"}}
      }.to change(Ownership, :count).by 1
      get "#{base_url}/ownership?owner_email=new_email@stuff.com"
      expect(response.status).to eq 200
      expect(response).to render_template(:ownership)
      expect(assigns(:new_email_assigned)).to be_falsey
      expect(assigns(:bike).owner_email).to eq "new_email@stuff.com"
    end
  end
  context "stolen bike" do
    let(:bike) { FactoryBot.create(:stolen_bike, :with_ownership_claimed) }
    it "renders" do
      get base_url
      expect(flash).to be_blank
      expect(response).to render_template(:theft_details)
      expect(assigns(:edit_template)).to eq "theft_details"
      expect(assigns(:edit_templates)).to eq theft_edit_templates.as_json
      expect(bike.user_id).to eq current_user.id
      expect(BikeDisplayer.display_edit_address_fields?(bike, current_user)).to be_falsey
      # It redirects "alert" to new_bike_promoted_alert, for backward compatibility
      # Maybe sometime after merging #2041, stop redirecting?
      get "#{base_url}?edit_template=alert"
      expect(response).to redirect_to(new_bike_promoted_alert_path(bike_id: bike.id))
      expect(flash).to be_blank
    end
    context "recovered bike" do
      before { bike.current_stolen_record.add_recovery_information }
      it "redirects to details" do
        # And if the bike is recovered, it redirects
        get "#{base_url}?edit_template=theft_details"
        expect(flash).to be_blank
        expect(response).to redirect_to(edit_bike_path(bike.id, edit_template: "bike_details"))
        expect(bike.reload.user_id).to eq current_user.id
        expect(BikeDisplayer.display_edit_address_fields?(bike, current_user)).to be_truthy
      end
    end
  end

  context "current_user has general alert" do
    before { current_user.update_column :alert_slugs, ["stolen_bike_without_location"] }
    it "renders the bike_details template" do
      get base_url
      expect(response).to be_ok
      expect(assigns(:edit_template)).to eq "bike_details"
      expect(assigns(:edit_templates)).to eq edit_templates.as_json
      expect(response).to render_template "bike_details"
      expect(assigns(:show_general_alert)).to be_truthy
      expect(session[:return_to]).to be_blank
    end
    context "stolen bike" do
      let!(:stolen_record) { FactoryBot.create(:stolen_record, bike: bike) }
      it "renders with stolen as first template, different description" do
        expect(bike.reload.status).to eq "status_stolen"
        expect(bike.current_stolen_record.without_location?).to be_truthy
        get base_url
        expect(response).to be_ok
        expect(assigns(:edit_template)).to eq "theft_details"
        expect(assigns(:edit_templates)).to eq theft_edit_templates.as_json
        expect(assigns(:show_general_alert)).to be_falsey
        expect(response).to render_template "theft_details"
      end
    end
    context "test all the edit templates" do
      let!(:stolen_record) { FactoryBot.create(:stolen_record, bike: bike) }
      let(:templates) do
        # Grab all the template keys from the controller so we can test that we
        # render all of them Both to ensure we get all of them and because we
        # can't use the let block
        bc = Bikes::EditsController.new
        bc.instance_variable_set(:@bike, Bike.new(status: "status_stolen"))
        # Don't test alert templates, they're in promoted alerts controller
        bc.edit_templates.keys - %w[alert alert_purchase_confirmation]
      end
      let(:no_global_alert_templates) { %w[theft_details photos report_recovered remove] }
      before { FactoryBot.create_list(:promoted_alert_plan, 3) }
      it "renders the template" do
        # Ensure stolen bike is set up correctly
        stolen_record.reload
        bike.reload
        expect(bike.current_stolen_record).to eq stolen_record
        expect(bike.current_stolen_record.without_location?).to be_truthy
        expect(stolen_record.promoted_alert_missing_photo?).to be_falsey
        templates.each do |template|
          get base_url, params: {id: bike.id, edit_template: template}

          expect(response.status).to eq(200)
          expect(response).to render_template(template)
          expect(assigns(:edit_template)).to eq(template)
          expect(assigns(:private_images)).to eq([]) if template == "photos"
          expect(assigns(:promoted_alerts)).to eq([]) if template == "alert"

          should_show_general_alert = no_global_alert_templates.exclude?(template)
          pp template unless assigns(:show_general_alert) == should_show_general_alert
          expect(assigns(:show_general_alert)).to eq should_show_general_alert
        end
      end
    end
  end

  context "with impound_record" do
    let!(:impound_record) { FactoryBot.create(:impound_record, bike: bike) }
    let(:target_edit_template_keys) { edit_templates.keys.map(&:to_s) - ["report_stolen"] + ["found_details"] }
    it "renders" do
      expect(bike.reload.status).to eq "status_impounded"
      expect(bike.owner&.id).to eq current_user.id
      expect(bike.authorized?(current_user)).to be_truthy
      get base_url
      expect(flash).to be_blank
      expect(response).to render_template(:bike_details)
      expect(assigns(:edit_templates).keys).to match_array(target_edit_template_keys)
      # it also renders the found bike page
      get "#{base_url}?edit_template=found_details"
      expect(flash).to be_blank
      expect(response).to render_template(:found_details)
      expect(assigns(:edit_templates).keys).to match_array(target_edit_template_keys)
    end
    context "organized impound_record" do
      let!(:impound_record) { FactoryBot.create(:impound_record_with_organization, bike: bike) }
      before { ProcessImpoundUpdatesJob.new.perform(impound_record.id) }
      it "redirects with flash error" do
        expect(bike.reload.status).to eq "status_impounded"
        get base_url
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
          get base_url
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
        let(:current_user) { FactoryBot.create(:organization_user, organization: impound_record.organization) }
        it "renders" do
          bike.reload
          expect(bike.claimed?).to be_truthy
          expect(bike.status).to eq "status_impounded"
          expect(bike.creator_unregistered_parking_notification?).to be_falsey
          expect(bike.bike_organizations.map(&:organization_id)).to eq([])
          expect(bike.authorized_by_organization?(u: current_user)).to be_truthy
          get base_url
          expect(flash).to be_blank
          expect(response).to render_template(:bike_details)
          expect(assigns(:bike).id).to eq bike.id
          expect(response).to render_template(:bike_details)
          # Found details go in organization edit
          expect(assigns(:edit_templates).keys).to match_array(target_edit_template_keys - ["found_details"])
        end
      end
    end
  end

  context "impounded unregistered_parking_notification by current_user" do
    let(:parking_notification) { FactoryBot.create(:parking_notification_unregistered, kind: "impound_notification") }
    let(:bike) { parking_notification.bike }
    let(:current_organization) { parking_notification.organization }
    let(:current_user) { parking_notification.user }
    before { ProcessParkingNotificationJob.new.perform(parking_notification.id) }
    it "renders" do
      parking_notification.reload
      impound_record = parking_notification.impound_record
      expect(impound_record).to be_present
      expect(bike.reload.ownerships.count).to eq 1
      ownership = bike.ownerships.first
      expect(ownership.self_made?).to be_truthy
      expect(ownership.user_id).to eq current_user.id
      expect(ownership.creator_unregistered_parking_notification?).to be_truthy
      expect(bike.current_impound_record&.id).to eq impound_record.id
      expect(bike.user).to eq current_user
      expect(bike.claimed?).to be_truthy
      expect(bike.creator_unregistered_parking_notification?).to be_truthy
      expect(bike.status).to eq "status_impounded"
      expect(bike.bike_organizations.map(&:organization_id)).to eq([current_organization.id])
      expect(bike.authorized?(current_user)).to be_truthy
      expect(bike.authorized_by_organization?(u: current_user)).to be_truthy # Because it's impounded
      get base_url
      expect(flash).to be_blank
      expect(response).to render_template(:bike_details)
      expect(assigns(:bike).id).to eq bike.id
    end
  end
end
