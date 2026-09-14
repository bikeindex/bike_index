require "rails_helper"

RSpec.describe "BikesController#update", type: :request do
  include_context :request_spec_logged_in_as_user_if_present
  let(:base_url) { "/bikes/#{bike.to_param}" }
  let(:ownership) { FactoryBot.create(:ownership) }
  let(:current_user) { ownership.creator }
  let(:bike) { ownership.bike }

  context "setting a bike_sticker" do
    it "gracefully fails if the number is weird" do
      expect(bike.bike_stickers.count).to eq 0
      patch base_url, params: {bike_sticker: "02891426438 "}
      expect(flash[:error]).to be_present
      bike.reload
      expect(bike.bike_stickers.count).to eq 0
    end
  end
  context "updating vehicle_type and propulsion_type" do
    it "ensures valid propulsion_type for cycle_type" do
      expect(bike.reload.cycle_type).to eq "bike"
      patch base_url, params: {bike: {propulsion_type: "pedal-assist"}}
      expect(flash[:success]).to be_present
      expect(bike.reload.propulsion_type).to eq "pedal-assist"

      patch base_url, params: {bike: {cycle_type: "stroller"}}
      expect(flash[:success]).to be_present
      expect(bike.reload.cycle_type).to eq "stroller"
      expect(bike.propulsion_type).to eq "throttle"

      patch base_url, params: {bike: {propulsion_type: "foot-pedal"}}
      expect(flash[:success]).to be_present
      expect(bike.reload.propulsion_type).to eq "human-not-pedal"
    end
  end
  context "setting address for bike" do
    let(:address_record) { FactoryBot.create(:address_record, :new_york) }
    let(:current_user) { FactoryBot.create(:user_confirmed, address_set_manually: true, address_record:) }
    let(:ownership) { FactoryBot.create(:ownership_claimed, creator: current_user, owner_email: current_user.email) }
    let(:primary_activity_id) { FactoryBot.create(:primary_activity).id }
    let(:update) do
      {address_record_attributes: {street: "10544 82 Ave NW", postal_code: "AB T6E 2A4", city: "Edmonton", country_id: Country.canada.id},
       primary_activity_id:}
    end
    let(:target_address_record_attributes) { update[:address_record_attributes].merge(kind: "bike", bike_id: bike.id) }
    include_context :geocoder_real # But it shouldn't make any actual calls!
    it "sets the address for the bike" do
      expect(current_user.to_coordinates).to eq([default_location[:latitude], default_location[:longitude]])
      bike.update(updated_at: Time.current, created_at: Time.current - 1.day)
      bike.reload
      expect(bike.updated_by_user_at).to eq bike.created_at
      expect(bike.not_updated_by_user?).to be_truthy
      expect(bike.current_ownership.claimed?).to be_truthy
      expect(bike.user&.id).to eq current_user.id
      expect(current_user.authorized?(bike)).to be_truthy
      expect(current_user.address_set_manually).to be_truthy

      expect(bike.address_set_manually).to be_falsey
      expect(bike.to_coordinates).to eq([default_location[:latitude], default_location[:longitude]])
      VCR.use_cassette("bike_request-set_manual_address") do
        Sidekiq::Job.clear_all
        Sidekiq::Testing.inline! do
          patch base_url, params: {bike: update}
        end
      end
      bike.reload
      expect(bike.address_set_manually).to be_falsey
      # I don't understand why this doesn't create an address record?
      expect(bike.address_record.street).to eq default_location[:street_address]
      # expect(bike.address_record).to match_hash_indifferently(target_address_record_attributes)
      expect(bike.updated_by_user_at).to be > (Time.current - 1)
      expect(bike.primary_activity_id).to eq primary_activity_id
      expect(bike.not_updated_by_user?).to be_falsey
    end
    context "with user without address" do
      let!(:current_user) { FactoryBot.create(:user_confirmed) }
      it "sets the passed address" do
        expect(current_user.to_coordinates).to eq([nil, nil])
        bike.update(updated_at: Time.current)
        bike.reload
        expect(current_user.authorized?(bike)).to be_truthy
        expect(current_user.address_set_manually).to be_falsey
        expect(bike.address_set_manually).to be_falsey
        expect(bike.owner&.id).to eq current_user.id
        expect(bike.user&.id).to eq current_user.id
        expect(bike.to_coordinates).to eq([nil, nil])

        VCR.use_cassette("bike_request-set_manual_address") do
          Sidekiq::Job.clear_all
          Sidekiq::Testing.inline! do
            expect do
              patch base_url, params: {bike: update}
            end.to change(AddressRecord, :count).by(2)
          end
        end
        expect(AddressRecord.pluck(:kind).sort).to eq(%w[bike user])
        bike.reload
        expect(bike.address_record).to have_attributes(target_address_record_attributes)
        expect(bike.address_set_manually).to be_truthy
        expect(bike.registration_address).to match_hash_indifferently(target_address_record_attributes.slice(:latitude, :longitude))
        # NOTE: There is an issue with coordinate precision locally vs on CI. It isn't relevant, so bypassing
        expect(bike.latitude).to be_within(0.01).of(53.5183351)
        expect(bike.longitude).to be_within(0.01).of(-113.5015663)
      end
    end
  end
  context "mark bike stolen, the way it's done on the web" do
    include_context :geocoder_real # But it shouldn't make any actual calls!
    it "marks bike stolen and doesn't set a location in Kansas!" do
      bike.reload
      expect(bike.status_stolen?).to be_falsey
      expect(bike.claimed?).to be_falsey
      expect(bike.authorized?(current_user)).to be_truthy
      CallbackJobs::AfterUserChangeJob.new.perform(current_user.id)
      expect(current_user.reload.alert_slugs).to eq([])
      Sidekiq::Job.clear_all
      Sidekiq::Testing.inline! do
        patch base_url, params: {
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
        patch base_url, params: {
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
      let(:address_record) { FactoryBot.create(:address_record, :new_york, bike:, kind: "bike") }
      let(:time) { Time.current - 10.minutes }
      let(:phone) { "2221114444" }
      let(:current_user) { FactoryBot.create(:user_confirmed, phone: phone) }
      let(:ownership) { FactoryBot.create(:ownership, owner_email: current_user.email) }
      # If the phone isn't already confirmed, it sends a confirmation message
      let!(:user_phone_confirmed) { FactoryBot.create(:user_phone_confirmed, user: current_user, phone: phone) }
      it "marks the bike stolen, doesn't set a location, blanks bike location" do
        expect(current_user.reload.phone).to eq "2221114444"
        bike.update(address_set_manually: true, address_record:)
        bike.reload
        expect(bike.address_set_manually).to be_truthy
        expect(bike.status_stolen?).to be_falsey
        expect(bike.claimed?).to be_falsey
        expect(bike.user&.id).to eq current_user.id
        CallbackJobs::AfterUserChangeJob.new.perform(current_user.id)
        expect(current_user.reload.alert_slugs).to eq([])
        expect(current_user.formatted_address_string(visible_attribute: :street)).to eq "278 Broadway, New York, NY 10007"
        expect(current_user.address_set_manually).to be_truthy
        # saving the bike one more time changes address_set_manually to be false
        # Someone surprising, but I think I'm happy with the outcome - it should be set by user
        bike.reload.update(updated_at: Time.current)
        expect(bike.reload.address_set_manually).to be_falsey
        Sidekiq::Job.clear_all
        Sidekiq::Testing.inline! do
          # get edit because it should claim the bike
          get "#{base_url}/edit"
          expect(bike.reload.claimed?).to be_truthy
          patch base_url, params: {
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
        # It no longer has an address, the stolen record has updated it
        expect(bike.address_hash.values.compact).to eq([])

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
    let(:auto_user) { FactoryBot.create(:organization_user, organization: current_organization) }
    let(:parking_notification) do
      current_organization.update(auto_user: auto_user)
      FactoryBot.create(:parking_notification_unregistered, organization: current_organization, user: current_organization.auto_user)
    end
    let!(:bike) { parking_notification.bike }
    let(:ownership1) { bike.ownerships.first }
    let(:current_user) { FactoryBot.create(:organization_user, organization: current_organization) }
    it "updates email and marks not user hidden" do
      bike.reload
      expect(bike.claimed?).to be_truthy
      expect(bike.bike_organizations.first.can_not_edit_claimed).to be_falsey
      expect(bike.creator_unregistered_parking_notification?).to be_truthy
      expect(bike.unregistered_parking_notification?).to be_truthy
      expect(bike.user_hidden).to be_truthy
      expect(bike.authorized_by_organization?(u: current_user)).to be_truthy
      expect(bike.ownerships.count).to eq 1
      expect(bike.send(:editable_organization_ids)).to eq([current_organization.id])
      expect(bike.to_coordinates.compact.count).to eq 2
      expect(bike.stolen_records.count).to eq 0

      expect(ownership1.user_hidden).to be_truthy
      expect(ownership1.current).to be_truthy
      expect(ownership1.organization_pre_registration).to be_truthy
      expect(ownership1.status).to eq "unregistered_parking_notification"
      expect(ownership1.origin).to eq "creator_unregistered_parking_notification"
      expect(parking_notification.reload.active?).to be_truthy
      expect(parking_notification.send_email?).to be_falsey
      expect(parking_notification.status).to eq "current"
      expect(parking_notification.kind).to eq "parked_incorrectly_notification"
      expect(parking_notification.retrieved_kind).to be_nil

      Sidekiq::Job.clear_all
      expect {
        patch base_url, params: {
          bike: {owner_email: "newuser@example.com"}
        }
        expect(flash[:success]).to be_present
      }.to change(Ownership, :count).by 1
      Sidekiq::Job.drain_all
      expect(bike.reload.ownerships.count).to eq 2

      expect(ownership1.reload.user_hidden).to be_truthy
      expect(ownership1.current).to be_falsey
      expect(ownership1.organization_pre_registration).to be_truthy
      expect(ownership1.status).to eq "unregistered_parking_notification"
      expect(ownership1.origin).to eq "creator_unregistered_parking_notification"
      ownership2 = bike.ownerships.last
      expect(ownership2.user_hidden).to be_falsey
      expect(ownership2.current).to be_truthy
      expect(ownership2.organization_pre_registration).to be_falsey
      expect(ownership2.new_registration?).to be_truthy
      expect(ownership2.status).to eq "status_with_owner"
      expect(ownership2.origin).to eq "transferred_ownership"

      expect(bike.claimed?).to be_falsey
      expect(bike.owner_email).to eq "newuser@example.com"
      expect(bike.current_ownership.user_id).to be_blank
      expect(bike.current_ownership_id).to eq ownership2.id
      expect(bike.current_ownership.owner_email).to eq "newuser@example.com"
      expect(bike.creator_unregistered_parking_notification?).to be_falsey
      expect(bike.stolen_records.count).to eq 0
      expect(bike.status).to eq "status_with_owner"
      expect(bike.user_hidden).to be_falsey
      expect(bike.serial_hidden?).to be_falsey
      expect(bike.send(:editable_organization_ids)).to eq([current_organization.id])
      expect(bike.authorized_by_organization?(org: current_organization)).to be_truthy # user is temporarily owner, so need to check org instead
      expect(bike.to_coordinates.compact.count).to eq 2

      expect(parking_notification.reload.active?).to be_falsey
      expect(parking_notification.send_email?).to be_falsey
      expect(parking_notification.status).to eq "retrieved"
      expect(parking_notification.kind).to eq "parked_incorrectly_notification"
      expect(parking_notification.retrieved_kind).to eq "ownership_transfer"
    end
    context "add extra information" do
      let(:auto_user) { current_user }
      it "updates, doesn't change status" do
        expect(bike.reload.current_ownership.owner_email).to eq current_user.email
        expect(ownership1.reload.user_hidden).to be_truthy
        expect(ownership1.current).to be_truthy
        expect(ownership1.organization_pre_registration).to be_truthy
        expect(ownership1.status).to eq "unregistered_parking_notification"
        expect(ownership1.origin).to eq "creator_unregistered_parking_notification"
        # bike.current_ownership.update(owner_email: current_user.email) # Can't figure out how to set this in the factory :(
        expect(bike.claimed?).to be_truthy
        expect(bike.authorized?(current_user)).to be_truthy
        expect(bike.creator_unregistered_parking_notification?).to be_truthy
        expect(bike.unregistered_parking_notification?).to be_truthy
        expect(bike.user_hidden).to be_truthy
        expect(bike.ownerships.count).to eq 1
        expect(bike.send(:editable_organization_ids)).to eq([current_organization.id])
        Sidekiq::Job.clear_all
        expect {
          patch base_url, params: {bike: {description: "sooo cool and stuff"}}
          expect(flash[:success]).to be_present
        }.to_not change(Ownership, :count)
        bike.reload
        expect(bike.description).to eq "sooo cool and stuff"
        expect(bike.creator_unregistered_parking_notification?).to be_truthy
        expect(bike.unregistered_parking_notification?).to be_truthy
        expect(bike.user_hidden).to be_truthy
        # And make sure it still can be rendered
        get "#{base_url}/edit"
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
    let!(:stolen_record) { FactoryBot.create(:stolen_record, :with_alert_image, bike: bike) }
    let(:state) { FactoryBot.create(:state_new_york) }
    let(:stolen_params) do
      {
        timezone: "America/Los_Angeles",
        date_stolen: "2020-04-28T11:00",
        phone: "111 111 1111",
        secondary_phone: "123 123 1234",
        country_id: Country.united_states.id,
        street: "278 Broadway",
        city: "New York",
        postal_code: "10007",
        region_record_id: state.id,
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

    context "with legacy stolen attribute names" do
      let(:legacy_stolen_params) do
        stolen_params.except(:postal_code, :region_record_id).merge(zipcode: "10007", state_id: state.id)
      end
      it "updates with the renamed attributes" do
        expect(bike.reload.current_stolen_record_id).to eq stolen_record.id
        patch base_url, params: {bike: {stolen: "true", stolen_records_attributes: {"0" => legacy_stolen_params}}}
        expect(flash[:success]).to be_present
        stolen_record.reload
        expect(stolen_record.street).to eq "278 Broadway"
        expect(stolen_record.postal_code).to eq "10007"
        expect(stolen_record.region_record_id).to eq state.id
      end
    end

    it "clears the existing alert image" do
      # Cassette required for alert image
      VCR.use_cassette("bike_request-stolen", match_requests_on: [:method], re_record_interval: 1.month) do
        expect(bike.reload.claimed?).to be_truthy
        expect(bike.owner&.id).to eq current_user.id
        FactoryBot.create(:alert_image, stolen_record:)
        stolen_record.reload
        expect(bike.current_stolen_record_id).to eq stolen_record.id
        expect(stolen_record.without_street?).to be_truthy
        og_alert_image_id = stolen_record.alert_image&.id # Fails without internet connection
        expect(og_alert_image_id).to be_present
        # Test stolen record phoning
        expect(stolen_record.phone_for_everyone).to be_falsey
        expect(stolen_record.phone_for_users).to be_truthy
        expect(stolen_record.phone_for_shops).to be_truthy
        expect(stolen_record.phone_for_police).to be_truthy
        CallbackJobs::AfterUserChangeJob.new.perform(current_user.id)
        expect(current_user.reload.alert_slugs).to eq(["stolen_bike_without_location"])
        current_user.update_column :updated_at, Time.current - 5.minutes
        Sidekiq::Job.clear_all
        Sidekiq::Testing.inline! do
          patch base_url, params: {
            bike: {stolen: "true", stolen_records_attributes: {"0" => stolen_params}}
          }
          expect(flash[:success]).to be_present
        end
        bike.reload
        # Unmemoize @current_alert_image
        stolen_record = StolenRecord.find(bike.current_stolen_record.id)
        stolen_record.current_alert_image
        stolen_record.reload

        expect(bike.current_stolen_record.id).to eq stolen_record.id
        expect(stolen_record.to_coordinates.compact).to eq([default_location[:latitude], default_location[:longitude]])
        expect(stolen_record.date_stolen).to be_within(5).of Time.at(1588096800)

        expect(stolen_record.phone).to eq "1111111111"
        expect(stolen_record.secondary_phone).to eq "1231231234"
        expect(stolen_record.country_id).to eq Country.united_states.id
        expect(stolen_record.region_record_id).to eq state.id
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

        expect(stolen_record.images_attached?).to be_truthy
      end

      expect(current_user.reload.alert_slugs).to eq([])
      # Test that we're bumping user, to bust cache
      expect(current_user.updated_at).to be > Time.current - 5
    end
  end
  context "updating impound_record" do
    let!(:impound_record) { FactoryBot.create(:impound_record, user: current_user, bike: bike) }
    let(:state) { FactoryBot.create(:state_new_york) }
    let(:impound_params) do
      {
        timezone: "America/Los_Angeles",
        impounded_at_with_timezone: "2020-04-28T11:00",
        address_record_attributes: {
          country_id: Country.united_states.id,
          street: "278 Broadway",
          city: "New York",
          postal_code: "10007",
          region_record_id: state.id
        }
      }
    end
    it "updates the impound_record" do
      bike.reload
      expect(bike.current_impound_record_id).to eq impound_record.id
      expect(bike.authorized?(current_user)).to be_truthy
      impound_record.reload
      expect(impound_record.address_record).to be_blank
      patch base_url, params: {
        bike: {impound_records_attributes: {"0" => impound_params}},
        edit_template: "found_details"
      }
      expect(flash[:success]).to be_present
      expect(response).to redirect_to(edit_bike_path(bike, edit_template: "found_details"))
      impound_record.reload
      expect(impound_record.address_record).to be_present
      expect(impound_record.address_record).to have_attributes(
        street: "278 Broadway",
        city: "New York"
      )
      expect(impound_record.impounded_at.to_i).to be_within(5).of 1588096800
    end

    context "updating with new owner email" do
      it "sends to the new owner" do
        expect {
          patch base_url, params: {
            bike: {owner_email: "newuser@example.com"}
          }
          expect(flash[:success]).to be_present
        }.to change(Ownership, :count).by 1
      end
    end
  end

  context "setting strava_gear" do
    let!(:strava_integration) { FactoryBot.create(:strava_integration, :synced, user: current_user) }
    let!(:road_bike_gear) do
      FactoryBot.create(:strava_gear, strava_integration:,
        strava_id: "b12345", name: "My Road Bike", gear_type: "bike")
    end
    let!(:mtb_gear) do
      FactoryBot.create(:strava_gear, strava_integration:,
        strava_id: "b67890", name: "My MTB", gear_type: "bike")
    end

    it "connects bike to strava gear" do
      expect(bike.strava_gear).to be_nil
      patch base_url, params: {strava_gear_id: "b12345", edit_template: "versions"}
      expect(flash[:success]).to match(/My Road Bike/)

      bike.reload
      expect(bike.strava_gear).to be_present
      expect(bike.strava_gear.strava_id).to eq("b12345")
      expect(bike.strava_gear.name).to eq("My Road Bike")
    end

    it "updates existing strava gear connection" do
      road_bike_gear.update(item: bike)

      patch base_url, params: {strava_gear_id: "b67890", edit_template: "versions"}
      expect(flash[:success]).to match(/My MTB/)

      bike.reload
      expect(bike.strava_gear.strava_id).to eq("b67890")
      expect(road_bike_gear.reload.item).to be_nil
    end

    it "disconnects strava gear when blank value" do
      road_bike_gear.update(item: bike)

      expect {
        patch base_url, params: {strava_gear_id: "", edit_template: "versions"}
      }.not_to change(StravaGear, :count)

      expect(flash[:success]).to match(/disconnected/)
      expect(road_bike_gear.reload.item).to be_nil
    end

    context "without strava integration" do
      before do
        strava_integration.destroy
        current_user.reload
      end

      it "shows error" do
        patch base_url, params: {strava_gear_id: "b12345", edit_template: "versions"}
        expect(flash[:error]).to match(/No synced Strava/)
      end
    end

    it "shows error for invalid gear id" do
      patch base_url, params: {strava_gear_id: "b99999", edit_template: "versions"}
      expect(flash[:error]).to match(/not found/)
    end
  end

  context "user not allowed to edit" do
    let(:current_user) { FactoryBot.create(:user_confirmed) }
    it "does not update and redirects" do
      patch base_url, params: {bike: {serial_number: "69"}}
      expect(response).to redirect_to bike_url(bike)
      expect(flash[:error]).to be_present
      expect(bike.reload.serial_number).to_not eq "69"
    end
  end

  context "example bike" do
    let(:organization) { FactoryBot.create(:organization) }
    before { bike.update(example: true, bike_organization_ids: [organization.id]) }

    it "updates, and leaves bike_organization_ids alone when they aren't passed" do
      expect(bike.reload.bike_organization_ids).to eq([organization.id])
      patch base_url, params: {bike: {description: "69"}}
      expect(response).to redirect_to edit_bike_url(bike)
      bike.reload
      expect(bike.description).to eq("69")
      expect(bike.bike_organization_ids).to eq([organization.id])
    end
  end

  context "marked_user_unhidden" do
    before { bike.update(marked_user_hidden: "1") }
    it "marks the bike unhidden" do
      expect(bike.reload.user_hidden).to be_truthy
      patch base_url, params: {bike: {marked_user_unhidden: "true"}}
      expect(bike.reload.user_hidden?).to be_falsey
    end
  end

  context "components" do
    let(:ownership) { FactoryBot.create(:ownership, bike: FactoryBot.create(:bike, :with_address_record)) }
    let!(:component1) { FactoryBot.create(:component, bike:) }
    let(:component2_attrs) do
      {
        _destroy: "0",
        ctype_id: component1.ctype_id,
        description: "sdfsdfsdf",
        manufacturer_id: bike.manufacturer_id.to_s,
        manufacturer_other: "stuffffffff",
        component_model: "asdfasdf",
        year: "1995",
        serial_number: "simple_serial"
      }
    end
    let(:bike_attrs) do
      {
        description: "69",
        handlebar_type: "other",
        owner_email: "  #{bike.owner_email.upcase}",
        organization_affiliation: "something weird",
        address_record_attributes: {city: "Rotterdam", postal_code: "3035",
                                    country_id: Country.netherlands.id, id: bike.address_record_id},
        components_attributes: {
          "0" => {"_destroy" => "1", :id => component1.id.to_s},
          Time.current.to_i.to_s => component2_attrs
        }
      }
    end

    it "replaces the component and updates the bike, without transferring ownership" do
      address_record = bike.address_record
      expect {
        patch base_url, params: {bike: bike_attrs}
      }.to change(Ownership, :count).by(0)
        .and change(AddressRecord, :count).by(0)

      expect(flash.to_h).to have_key("success")
      expect(response).to redirect_to edit_bike_url(bike)
      expect(assigns(:bike)).to be_present
      bike.reload
      expect(bike).to have_attributes(description: "69", handlebar_type: "other", user_hidden: false,
        organization_affiliation: "something weird", address_record_id: address_record.id)

      expect(address_record.reload).to have_attributes(postal_code: "3035", city: "Rotterdam")
      expect(address_record.country&.name).to eq(Country.netherlands.name)

      expect(bike.components.count).to eq 1
      expect(bike.components.where(id: component1.id).any?).to be_falsey
      component2_attrs.except(:_destroy).each do |key, value|
        expect(bike.components.first.send(key).to_s).to eq value.to_s
      end
    end
  end

  context "bike_sticker" do
    let(:bike_attrs) { {description: "42", handlebar_type: "drop_bar"} }
    let!(:bike_sticker) { FactoryBot.create(:bike_sticker, code: "a00100") }

    it "updates and claims the sticker from a scanned URL" do
      expect(bike.bike_stickers.count).to eq 0
      patch base_url, params: {bike: bike_attrs, bike_sticker: "https://bikeindex.org/bikes/scanned/A100?organization_id=europe"}
      expect(flash[:success]).to match(bike_sticker.pretty_code)
      bike.reload
      expect(bike).to have_attributes(description: "42", handlebar_type: "drop_bar")
      expect(bike.bike_stickers.count).to eq 1
      expect(bike_sticker.reload).to have_attributes(claimed?: true, bike:, user: current_user)
    end

    context "bike already has a sticker" do
      let!(:bike_sticker_claimed) { FactoryBot.create(:bike_sticker_claimed, bike:, user: current_user) }

      it "claims another sticker without removing the existing one" do
        expect(bike.bike_stickers.count).to eq 1
        expect {
          patch base_url, params: {bike: bike_attrs, bike_sticker: "A 100"}
        }.to change(BikeStickerUpdate, :count).by 1
        expect(BikeStickerUpdate.last.kind).to eq "initial_claim"
        expect(flash[:success]).to match(bike_sticker.pretty_code)
        bike.reload
        expect(bike).to have_attributes(description: "42", handlebar_type: "drop_bar")
        expect(bike.bike_stickers.count).to eq 2
        expect(bike_sticker.reload).to have_attributes(claimed?: true, bike:, user: bike.creator)
      end

      context "over the unorganized claim limit" do
        before { stub_const("BikeSticker::MAX_UNORGANIZED", 1) }
        let!(:bike_sticker_update) { FactoryBot.create(:bike_sticker_update, user: current_user) }

        it "records a failed claim and renders an error" do
          expect(bike_sticker.claimable_by?(current_user)).to be_falsey
          expect {
            patch base_url, params: {bike: bike_attrs, bike_sticker: "A 100"}
          }.to change(BikeStickerUpdate, :count).by 1
          expect(BikeStickerUpdate.last).to have_attributes(kind: "failed_claim", organization_kind: "no_organization",
            user_id: current_user.id, bike_id: bike.id, bike_sticker_id: bike_sticker.id)
          expect(bike_sticker.reload.claimed?).to be_falsey

          expect(flash[:error]).to be_present
          bike.reload
          expect(bike).to have_attributes(description: "42", handlebar_type: "drop_bar")
          expect(bike.bike_stickers.count).to eq 1
        end
      end
    end

    context "sticker not found" do
      it "renders an error, still updating the bike" do
        expect(bike.bike_stickers.count).to eq 0
        patch base_url, params: {bike: bike_attrs, bike_sticker: "A 150"}
        expect(flash[:error]).to be_present
        bike.reload
        expect(bike).to have_attributes(description: "42", handlebar_type: "drop_bar")
        expect(bike.bike_stickers.count).to eq 0
      end
    end
  end

  context "owner email changes" do
    let(:email) { "originalemail@example.com" }
    let(:new_email) { "new@email.com" }
    let(:current_user) { FactoryBot.create(:user_confirmed, email:) }
    let(:ownership) { FactoryBot.create(:ownership, creator: current_user, owner_email: "otheroriginal@email.com") }

    def expect_bike_transferred_but_unclaimed(bike)
      bike.reload
      ownership.reload
      expect(ownership.current?).to be_falsey
      expect(bike).to have_attributes(owner_email: new_email, user: nil, claimed?: false, owner: current_user)
      expect(bike.current_ownership.id).to_not eq ownership.id
      expect(bike.current_ownership).to have_attributes(creator_id: current_user.id, owner_email: new_email, user: nil)
      expect(bike.authorized?(current_user)).to be_truthy

      expect(ActionMailer::Base.deliveries.count).to eq 1
      mail = ActionMailer::Base.deliveries.last
      expect(mail.subject).to eq("Confirm your Bike Index registration")
      expect(mail.reply_to).to eq(["contact@bikeindex.org"])
      expect(mail.from).to eq(["contact@bikeindex.org"])
      expect(mail.to).to eq([new_email])
    end

    before do
      bike.reload
      ActionMailer::Base.deliveries = []
      Sidekiq::Job.clear_all
    end

    it "creates a new ownership and emails the new owner" do
      expect(bike.claimed?).to be_falsey
      expect(bike.authorized?(current_user)).to be_truthy
      expect {
        patch base_url, params: {bike: {owner_email: new_email}}
      }.to change(Ownership, :count).by(1)
      Sidekiq::Job.drain_all
      expect_bike_transferred_but_unclaimed(bike)
    end

    context "claimed ownership" do
      let(:ownership) { FactoryBot.create(:ownership_claimed, user: current_user, owner_email: email) }

      it "creates a new ownership and emails the new owner" do
        expect(bike.owner_email).to eq email
        expect(bike.claimed?).to be_truthy
        expect(bike.user).to eq current_user
        expect {
          patch base_url, params: {bike: {owner_email: "#{new_email.upcase} "}}
        }.to change(Ownership, :count).by(1)
        Sidekiq::Job.drain_all
        expect_bike_transferred_but_unclaimed(bike)
      end
    end
  end

  context "with a stored return_to" do
    let(:return_to) { "/about" }
    # Landing on the sign in form with a return_to is what stores one
    before { get "/session/new", params: {return_to:} }

    it "redirects to it" do
      patch base_url, params: {bike: {description: "69", marked_user_hidden: "0"}}
      expect(bike.reload.description).to eq("69")
      expect(response).to redirect_to return_to
      expect(session[:return_to]).to be_nil
    end

    context "an off-site url" do
      let(:return_to) { "http://testhost.com/bad_place" }
      it "ignores it" do
        patch base_url, params: {bike: {description: "69", marked_user_hidden: "0"}}
        expect(bike.reload.description).to eq("69")
        expect(session[:return_to]).to be_nil
        expect(response).to redirect_to edit_bike_url(bike)
      end
    end
  end

  # Applying stolen changes through stolen_records_attributes, and returning to the edit_template
  context "stolen update through stolen_records_attributes" do
    include_context :geocoder_real
    let!(:state) { State.find_or_create_by(name: "Illinois", abbreviation: "IL", country: Country.united_states) }
    let(:country) { state.country }
    let!(:stolen_record) { FactoryBot.create(:stolen_record, bike:, city: "party") }
    let(:target_time) { 1454925600 }
    let(:stolen_attrs) do
      {
        date_stolen: "2016-02-08 04:00:00",
        timezone: "America/Chicago",
        phone: "9999999999",
        street: "66666666 foo street ,",
        country_id: country.id,
        city: "Chicago ", # people commonly paste a trailing comma
        postal_code: "60647 , ",
        region_record_id: state.id,
        locking_description: "Some description",
        lock_defeat_description: "It was cuttttt",
        theft_description: "Someone stole it and stuff",
        police_report_number: "#444444",
        police_report_department: "department of party",
        secondary_phone: "8888888888",
        proof_of_ownership: 1,
        receive_notifications: 0,
        estimated_value: "1200"
      }
    end
    let(:bike_attrs) { {date_stolen: Time.current.to_i, stolen_records_attributes: {"0" => stolen_attrs}} }
    let(:skipped_attrs) { %i[street city postal_code proof_of_ownership receive_notifications timezone date_stolen estimated_value] }

    it "updates and returns to the edit_template" do
      VCR.use_cassette("bikes_controller-create-stolen", match_requests_on: [:path]) do
        expect(stolen_record).to have_attributes(receive_notifications: true, no_notify: false)
        expect(stolen_record.proof_of_ownership).to be_falsey
        bike.reload
        expect(bike.current_stolen_record).to eq stolen_record
        expect(bike.status).to eq "status_stolen"

        patch base_url, params: {bike: bike_attrs, edit_template: "fancy_template"}
        expect(flash[:error]).to_not be_present
        expect(response).to redirect_to edit_bike_url(bike, edit_template: "fancy_template")
        bike.reload
        expect(bike.status).to eq "status_stolen"
        expect(bike.stolen_records.count).to eq 1
        expect(bike.fetch_current_stolen_record.id).to eq stolen_record.id

        current_stolen_record = bike.fetch_current_stolen_record
        expect(current_stolen_record.date_stolen.to_i).to be_within(1).of target_time
        expect(current_stolen_record).to have_attributes(proof_of_ownership: true, receive_notifications?: false,
          no_notify?: true, estimated_value: 1200, city: "Chicago", postal_code: "60647", street: "66666666 foo street")
        stolen_attrs.except(*skipped_attrs).each do |key, value|
          expect(current_stolen_record.send(key)).to eq value
        end
      end
    end

    context "canadian stolen record" do
      let!(:canada) { Country.canada }
      let(:stolen_attrs) do
        super().merge(street: "2222 Cambridge St.,", country_id: canada.id, city: "Vancouver\n, ",
          postal_code: "v5l1E6", locking_description: "I locked it up!", lock_defeat_description: "",
          theft_description: "I deeply care about this bike, nefariousness!", police_report_number: "#666",
          police_report_department: "Vancouver", estimated_value: "5200")
      end

      it "updates, ignoring the passed state" do
        VCR.use_cassette("bikes_controller-create-stolen-canada", match_requests_on: [:path]) do
          expect(bike.reload.fetch_current_stolen_record).to eq stolen_record
          patch base_url, params: {bike: bike_attrs, edit_template: "fancy_template"}
          expect(flash[:error]).to_not be_present
          expect(response).to redirect_to edit_bike_url(bike, edit_template: "fancy_template")
          bike.reload
          expect(bike.status).to eq "status_stolen"
          expect(bike.stolen_records.count).to eq 1
          expect(bike.fetch_current_stolen_record.id).to eq stolen_record.id

          current_stolen_record = bike.fetch_current_stolen_record
          expect(current_stolen_record.date_stolen.to_i).to be_within(1).of target_time
          expect(current_stolen_record).to have_attributes(proof_of_ownership: true, receive_notifications: false,
            estimated_value: 5200, region_record_id: nil, country_id: Country.canada.id,
            city: "Vancouver", postal_code: "V5L 1E6", street: "2222 Cambridge St.")
          expect(current_stolen_record.latitude).to be_within(0.001).of(49.1573)
          expect(current_stolen_record.longitude).to be_within(0.001).of(-123.9664322)
          stolen_attrs.except(:region_record_id, *skipped_attrs).each do |key, value|
            expect(current_stolen_record.send(key)).to eq value
          end
        end
      end
    end
  end

  context "owner present, bike organizations" do
    let(:current_user) { FactoryBot.create(:user_confirmed) }
    let(:bike) { FactoryBot.create(:bike_organized, owner_email: current_user.email) }
    let(:ownership) { bike.ownerships.first }
    let(:organization) { bike.organizations.first }
    let(:organization2) { FactoryBot.create(:organization) }
    let(:color) { Color.black }
    let(:allowed_attributes) do
      {
        description: "69 description",
        marked_user_hidden: "0",
        primary_frame_color_id: color.id,
        secondary_frame_color_id: color.id,
        tertiary_frame_color_id: Color.black.id,
        handlebar_type: "other",
        coaster_brake: true,
        belt_drive: true,
        front_gear_type_id: FactoryBot.create(:front_gear_type).id,
        rear_gear_type_id: FactoryBot.create(:rear_gear_type).id,
        owner_email: "new_email@stuff.com",
        year: 1993,
        frame_model: "A sweet model named things",
        frame_size: "56cm",
        name: "a sweet name for a bike",
        extra_registration_number: "some weird other number",
        bike_organization_ids: "#{organization2.id}, #{organization.id}"
      }
    end
    let(:target_attributes) { allowed_attributes.except(:marked_user_hidden, :bike_organization_ids) }
    before { ownership.mark_claimed }

    it "updates with the allowed attributes, and lets the named organization edit" do
      expect(ownership.reload.owner).to eq current_user
      patch base_url, params: {bike: allowed_attributes, organization_ids_can_edit_claimed: [organization2.id]}
      expect(response).to redirect_to edit_bike_url(bike)
      expect(assigns(:bike)).to be_present
      bike.reload
      expect(bike.user_hidden).to be_falsey
      expect(bike).to have_attributes target_attributes
      expect(bike.bike_organization_ids).to match_array([organization.id, organization2.id])
      expect(bike.send(:editable_organization_ids)).to eq([organization2.id])
    end

    context "organization_ids_can_edit_claimed_present" do
      it "updates, letting no organization edit" do
        patch base_url, params: {bike: allowed_attributes, organization_ids_can_edit_claimed_present: "1"}
        expect(response).to redirect_to edit_bike_url(bike)
        bike.reload
        expect(bike.user_hidden).to be_falsey
        expect(bike).to have_attributes target_attributes
        expect(bike.bike_organization_ids).to match_array([organization.id, organization2.id])
        expect(bike.send(:editable_organization_ids)).to eq([])
      end

      it "replaces the creation organization when only the new one is passed" do
        expect(bike.reload.bike_organization_ids).to eq([organization.id])
        expect(bike.creation_organization_id).to eq organization.id
        patch base_url, params: {edit_template: "groups", organization_ids_can_edit_claimed: "true",
                                 bike: {bike_organization_ids: organization2.id.to_s}}
        expect(response).to redirect_to edit_bike_url(bike, edit_template: "groups")
        bike.reload
        expect(bike.creation_organization_id).to eq organization.id
        expect(bike.bike_organization_ids).to match_array([organization2.id])
        # A newly added organization starts out unable to edit
        expect(bike.send(:editable_organization_ids)).to eq([])
      end
    end
  end

  context "organized bike, member present" do
    let(:organization) { FactoryBot.create(:organization) }
    let(:can_edit_claimed) { false }
    let(:claimed) { false }
    let(:bike) { FactoryBot.create(:bike_organized, :with_ownership, creation_organization: organization, can_edit_claimed:, claimed:) }
    let(:current_user) { FactoryBot.create(:organization_user, organization:) }

    it "updates the bike" do
      bike.reload
      expect(bike.owner).to_not eq(current_user)
      expect(bike.send(:editable_organization_ids)).to eq([organization.id])
      expect(bike.authorized_by_organization?(u: current_user)).to be_truthy
      patch base_url, params: {bike: {description: "new description", handlebar_type: "forward",
                                      frame_size: "50cm", frame_size_number: 54, frame_size_unit: "cm"}}
      expect(response).to redirect_to edit_bike_url(bike)
      bike.reload
      expect(bike).to have_attributes(user_hidden: false, description: "new description", handlebar_type: "forward",
        frame_size_unit: "cm", frame_size_number: 54, frame_size: "54cm")
      expect(bike.send(:editable_organization_ids)).to eq([organization.id])
    end

    context "bike is claimed" do
      let(:claimed) { true }
      it "fails to update" do
        bike.reload
        expect(bike.send(:editable_organization_ids)).to eq([])
        expect(bike.authorized_by_organization?(u: current_user)).to be_falsey
        patch base_url, params: {bike: {description: "new description", handlebar_type: "forward"}}
        expect(flash[:error]).to be_present
        expect(bike.reload.description).to_not eq "new description"
      end

      context "can_edit_claimed true" do
        let(:can_edit_claimed) { true }
        it "updates the bike" do
          bike.reload
          expect(bike.send(:editable_organization_ids)).to eq([organization.id])
          expect(bike.authorized_by_organization?(u: current_user)).to be_truthy
          patch base_url, params: {bike: {description: "new description", handlebar_type: "forward"}}
          expect(response).to redirect_to edit_bike_url(bike)
          bike.reload
          expect(bike).to have_attributes(user_hidden: false, description: "new description", handlebar_type: "forward")
        end
      end
    end
  end
end
