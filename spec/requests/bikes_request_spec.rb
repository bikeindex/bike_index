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

  describe "new" do
    before { Country.united_states && Organization.example } # Read replica
    it "renders" do
      get "#{base_url}/new"
      expect(response.code).to eq("200")
      expect(assigns(:b_param).revised_new?).to be_truthy
      bike = assigns(:bike)
      expect(bike.status).to eq "status_with_owner"
      expect(bike.stolen_records.last).to be_blank
      expect(response).to render_template(:new)
      expect(response.body).to match("<title>Register a bike!</title>")
      expect(response.body).to match('<meta name="description" content="Register a bike on Bike Index quickly')
      # This still wouldn't show address, because it doesn't have an organization with BikeServices::Builder.include_address_record?
      expect(BikeServices::Displayer.display_edit_address_fields?(bike, current_user)).to be_truthy
    end
    context "with bike_sticker" do
      let(:organization) { FactoryBot.create(:organization) }
      let!(:bike_sticker) { FactoryBot.create(:bike_sticker, code: "UC1101", organization: organization) }
      it "renders with bike sticker" do
        get "#{base_url}/new?bike_sticker=uc1101"
        expect(response.code).to eq("200")
        b_param = assigns(:b_param)
        expect(b_param.revised_new?).to be_truthy
        expect(b_param.origin).to eq "sticker"
        expect(b_param.bike_sticker_code).to eq bike_sticker.pretty_code
        expect(b_param.creation_organization&.id).to eq organization.id
        bike = assigns(:bike)
        expect(bike.status).to eq "status_with_owner"
        expect(bike.stolen_records.last).to be_blank
        expect(bike.creation_organization_id).to eq organization.id
        expect(bike.bike_sticker).to eq "UC 110 1" # pretty code
        expect(response).to render_template(:new)
      end
    end
    context "with organization" do
      let!(:organization) { FactoryBot.create(:organization) }

      it "renders with organization" do
        get "#{base_url}/new?organization_id=#{organization.slug}"
        expect(response.code).to eq("200")
        expect(response).to render_template(:new)
        expect(assigns(:bike).creation_organization_id).to eq organization.id
        expect(assigns(:bike).primary_frame_color_id).to be_nil
        expect(assigns(:bike).address_record).to be_blank
      end

      context "existing b_param with creation_organization_id" do
        let(:organization2) { FactoryBot.create(:organization_with_organization_features, kind: :school, enabled_feature_slugs: "reg_address") }
        let(:b_param) { FactoryBot.create(:b_param, params: {bike: bike_params}) }
        let(:manufacturer_id) { FactoryBot.create(:manufacturer).id }
        let(:bike_params) do
          {owner_email: current_user.email, manufacturer_id:, creation_organization_id: organization2.id,
           address: "212 Main St", address_city: "Chicago", address_state: "IL", address_zipcode: "60647"}
        end
        let(:target_address_attrs) { {street: "212 Main St", city: "Chicago", region_string: "IL", postal_code: "60647", kind: "ownership"} }

        it "uses the existing organization" do
          expect(b_param.reload.id_token).to be_present
          get "#{base_url}/new?organization_id=#{organization.slug}&b_param_token=#{b_param.id_token}"
          expect(response.code).to eq("200")
          expect(response).to render_template(:new)
          expect(assigns(:bike).creation_organization_id).to eq organization2.id
          expect(assigns(:bike).manufacturer_id).to eq manufacturer_id
          expect(assigns(:bike).primary_frame_color_id).to be_nil

          expect(response.body).to match("Campus mailing address")
          address_record = assigns(:bike).address_record
          expect(address_record).to have_attributes target_address_attrs
        end
      end
    end
    context "stolen from params" do
      it "renders a new stolen bike" do
        get "#{base_url}/new?stolen=true"
        expect(response.code).to eq("200")
        expect(assigns(:b_param).revised_new?).to be_truthy
        bike = assigns(:bike)
        expect(bike.status).to eq "status_stolen"
        expect(bike.stolen_records.last).to be_present
        expect(bike.stolen_records.last.country_id).to eq Country.united_states_id
        expect(response).to render_template(:new)
        expect(response.body).to match("<title>Register a stolen bike</title>")
        expect(response.body).to match('<meta name="description" content="Register a stolen bike on Bike Index quickly')
        # Make sure it renders without address fields for a stolen bikes
        expect(BikeServices::Displayer.display_edit_address_fields?(bike, current_user)).to be_falsey
      end
      context "with address in different country" do
        let(:ownership) { FactoryBot.create(:ownership, creator: current_user) }
        let(:current_user) { FactoryBot.create(:user, :with_address_record, address_in: :edmonton) }

        it "renders a new stolen bike from status" do
          get "#{base_url}/new?status=stolen"
          expect(response.code).to eq("200")
          bike = assigns(:bike)
          expect(bike.status_humanized).to eq "stolen"
          expect(bike.stolen_records.last).to be_present
          expect(bike.stolen_records.last.country_id).to eq Country.canada_id
          expect(response).to render_template(:new)
        end
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

        expect(response.body).to match "Where was it found?"
      end
      it "found is impounded" do
        get "#{base_url}/new?status=found"
        expect(response.code).to eq("200")
        bike = assigns(:bike)
        expect(bike.status).to eq "status_impounded"
        expect(bike.impound_records.last).to be_present
        expect(response).to render_template(:new)
        expect(response.body).to match "Where was it found?"
      end
    end
  end

  describe "resolve_token" do
    context "graduated_notification" do
      let(:graduated_notification) { FactoryBot.create(:graduated_notification_bike_graduated) }
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
        expect(graduated_notification.marked_remaining_by&.id).to be_blank
        expect(bike.bike_organizations.pluck(:organization_id)).to eq([organization.id])
      end
      context "current_user present" do
        let(:current_user) { FactoryBot.create(:user_confirmed) }
        it "marked_remaining_by user" do
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
          expect(graduated_notification.marked_remaining_by&.id).to eq current_user.id
          expect(graduated_notification.user_id).to_not eq current_user.id
          expect(graduated_notification.marked_remaining_by&.id).to eq current_user.id
          expect(bike.bike_organizations.pluck(:organization_id)).to eq([organization.id])
        end
      end
      context "with associated_notifications" do
        let(:graduated_notification) { FactoryBot.create(:graduated_notification) } # so that it isn't processed prior to second creation
        let(:bike2) { FactoryBot.create(:bike_organized, :with_ownership, creation_organization: organization, owner_email: bike.owner_email, created_at: bike.created_at + 1.hour) }
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
          expect(graduated_notification.marked_remaining_by_id).to be_blank
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
          expect(graduated_notification.status).to eq("bike_graduated")
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
          ProcessParkingNotificationJob.new.perform(parking_notification_abandoned.id)
          expect(parking_notification_abandoned.reload.status).to eq "current"
          parking_notification.reload
          expect(parking_notification.status).to eq "replaced"
          expect(parking_notification.active?).to be_truthy
          expect(parking_notification.resolved?).to be_falsey
          Sidekiq::Job.clear_all
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
          ProcessParkingNotificationJob.new.perform(parking_notification_impounded.id)
          parking_notification.reload
          expect(parking_notification.status).to eq "replaced"
          expect(parking_notification.active?).to be_falsey
          expect(bike.reload.status).to eq "status_impounded"
          Sidekiq::Job.clear_all
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

  describe "scanned" do
    let(:organization) { FactoryBot.create(:organization) }
    let(:organization2) { FactoryBot.create(:organization) }
    let!(:bike_sticker1) { FactoryBot.create(:bike_sticker, code: "UC1101", organization: organization) }
    it "redirects to scanned" do
      get "/bikes/scanned/UC1101"
      expect(response).to render_template("scanned")
      expect(assigns(:bike_sticker)&.id).to eq bike_sticker1.id
      get "/bikes/scanned/uc1101"
      expect(response).to render_template("scanned")
      expect(assigns(:bike_sticker)&.id).to eq bike_sticker1.id
      get "/bikes/scanned/UC01101"
      expect(response).to render_template("scanned")
      expect(assigns(:bike_sticker)&.id).to eq bike_sticker1.id
      # Note: this MUST always work from here on out - it fixes urls from batch #35 and #38
      # We have to assume these stickers are always around
      get "/bikes/scannedUC01101"
      expect(response).to redirect_to("/bikes/UC01101/scanned")
      get "/bikes/scannedUC01101?organization_id=UCLA"
      expect(response).to redirect_to("/bikes/UC01101/scanned?organization_id=UCLA")
      # NOTE: this fixes batch #42, which was another printing fuckup
      # We have to assume these stickers will always be around too :/
      get "/bikes/scanned/UC01101organization_id=UCLA"
      expect(response).to render_template("scanned")
      expect(assigns(:bike_sticker)&.id).to eq bike_sticker1.id
      expect(assigns(:organization))
    end
    context "UI" do
      let!(:bike_sticker2) { FactoryBot.create(:bike_sticker, code: "UI1101", organization: organization) }
      let!(:bike_sticker3) { FactoryBot.create(:bike_sticker, code: "U1101", organization: organization2) }
      it "redirects" do
        # And UI
        get "/bikes/scanned/UI01101"
        expect(response).to render_template("scanned")
        expect(assigns(:bike_sticker)&.id).to eq bike_sticker2.id
        get "/bikes/scanned/Ui01101"
        expect(response).to render_template("scanned")
        expect(assigns(:bike_sticker)&.id).to eq bike_sticker2.id
        get "/bikes/scannedUI001101?organization_id=UCLA"
        expect(response).to redirect_to("/bikes/UI001101/scanned?organization_id=UCLA")
        # And final sticker
        get "/bikes/scanned/U01101"
        expect(response).to render_template("scanned")
        expect(assigns(:bike_sticker)&.id).to eq bike_sticker3.id
        get "/bikes/scannedU01101"
        expect(response.status).to eq 404
      end
    end
  end
end
