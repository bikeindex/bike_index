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
      {street: "10544 82 Ave NW", zipcode: "AB T6E 2A4", city: "Edmonton", country_id: Country.canada.id, state_id: "",
       primary_activity_id:}
    end
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
      expect(bike.street).to eq default_location[:street_address]
      expect(bike.address_set_manually).to be_falsey
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
            patch base_url, params: {bike: update}
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
  end
  context "mark bike stolen, the way it's done on the web" do
    include_context :geocoder_real # But it shouldn't make any actual calls!
    it "marks bike stolen and doesn't set a location in Kansas!" do
      bike.reload
      expect(bike.status_stolen?).to be_falsey
      expect(bike.claimed?).to be_falsey
      expect(bike.authorized?(current_user)).to be_truthy
      AfterUserChangeJob.new.perform(current_user.id)
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
      let(:location_attrs) { {country_id: Country.united_states.id, city: "New York", street: "278 Broadway", zipcode: "10007", latitude: 40.7143528, longitude: -74.0059731, address_set_manually: true} }
      let(:time) { Time.current - 10.minutes }
      let(:phone) { "2221114444" }
      let(:current_user) { FactoryBot.create(:user_confirmed, phone: phone) }
      let(:ownership) { FactoryBot.create(:ownership, owner_email: current_user.email) }
      # If the phone isn't already confirmed, it sends a confirmation message
      let!(:user_phone_confirmed) { FactoryBot.create(:user_phone_confirmed, user: current_user, phone: phone) }
      it "marks the bike stolen, doesn't set a location, blanks bike location" do
        expect(current_user.reload.phone).to eq "2221114444"
        bike.update(location_attrs.merge(skip_geocoding: true))
        bike.reload
        expect(bike.address_set_manually).to be_truthy
        expect(bike.status_stolen?).to be_falsey
        expect(bike.claimed?).to be_falsey
        expect(bike.user&.id).to eq current_user.id
        AfterUserChangeJob.new.perform(current_user.id)
        expect(current_user.reload.alert_slugs).to eq([])
        expect(current_user.formatted_address_string(visible_attribute: :street)).to eq "278 Broadway, New York, 10007"
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
        expect(bike.address_hash.values.compact).to eq(["US"])

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
      expect(bike.editable_organizations.pluck(:id)).to eq([current_organization.id])
      expect(bike.stolen_records.count).to eq 0
      expect(ownership1.user_hidden).to be_truthy
      expect(ownership1.current).to be_truthy
      expect(ownership1.organization_pre_registration).to be_truthy
      expect(ownership1.status).to eq "unregistered_parking_notification"
      expect(ownership1.origin).to eq "creator_unregistered_parking_notification"
      Sidekiq::Job.clear_all
      expect {
        patch base_url, params: {
          bike: {owner_email: "newuser@example.com"}
        }
        expect(flash[:success]).to be_present
      }.to change(Ownership, :count).by 1
      Sidekiq::Job.drain_all
      expect(bike.reload.ownerships.count).to eq 2
      expect(ownership1.reload.user_hidden).to be_falsey # Meh, maybe not ideal? But convenient
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
      expect(bike.current_ownership.user_id).to be_blank
      expect(bike.current_ownership_id).to eq ownership2.id
      expect(bike.current_ownership.owner_email).to eq "newuser@example.com"
      expect(bike.creator_unregistered_parking_notification?).to be_falsey
      expect(bike.stolen_records.count).to eq 0
      expect(bike.status).to eq "status_with_owner"
      expect(bike.user_hidden).to be_falsey
      expect(bike.editable_organizations.pluck(:id)).to eq([current_organization.id])
      expect(bike.authorized_by_organization?(org: current_organization)).to be_truthy # user is temporarily owner, so need to check org instead
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
        expect(bike.editable_organizations.pluck(:id)).to eq([current_organization.id])
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
        FactoryBot.create(:alert_image, stolen_record:)
        stolen_record.reload
        expect(bike.current_stolen_record_id).to eq stolen_record.id
        expect(stolen_record.without_location?).to be_truthy
        og_alert_image_id = stolen_record.alert_image&.id # Fails without internet connection
        expect(og_alert_image_id).to be_present
        # Test stolen record phoning
        expect(stolen_record.phone_for_everyone).to be_falsey
        expect(stolen_record.phone_for_users).to be_truthy
        expect(stolen_record.phone_for_shops).to be_truthy
        expect(stolen_record.phone_for_police).to be_truthy
        AfterUserChangeJob.new.perform(current_user.id)
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
      patch base_url, params: {
        bike: {impound_records_attributes: {"0" => impound_params}},
        edit_template: "found_details"
      }
      expect(flash[:success]).to be_present
      expect(response).to redirect_to(edit_bike_path(bike, edit_template: "found_details"))
      impound_record.reload
      expect(impound_record.latitude).to be_present
      expect(impound_record.impounded_at.to_i).to be_within(5).of 1588096800
      expect(impound_record).to match_hash_indifferently impound_params.except(:impounded_at_with_timezone, :timezone)
    end
  end
end
