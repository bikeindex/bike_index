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
      it "marks the bike remaining" do
        graduated_notification.reload
        bike.reload
        expect(graduated_notification.processed?).to be_truthy
        expect(graduated_notification.marked_remaining_link_token).to be_present
        expect(bike.graduated?(organization)).to be_truthy
        expect(bike.bike_organizations.pluck(:organization_id)).to eq([])
        get "#{base_url}/#{bike.id}?graduated_notification_remaining=#{graduated_notification.marked_remaining_link_token}"
        expect(assigns(:bike)).to eq bike
        expect(flash[:success]).to be_present
        bike.reload
        graduated_notification.reload
        expect(bike.graduated?(organization)).to be_falsey
        expect(graduated_notification.marked_remaining?).to be_truthy
        expect(bike.bike_organizations.pluck(:organization_id)).to eq([organization.id])
      end
      context "already marked recovered" do
        let(:graduated_notification) { FactoryBot.create(:graduated_notification, :marked_remaining) }
        it "doesn't update, but flash success" do
          og_marked_remaining_at = graduated_notification.marked_remaining_at
          expect(og_marked_remaining_at).to be_present
          expect(bike.graduated?(organization)).to be_falsey
          expect(bike.bike_organizations.pluck(:organization_id)).to eq([organization.id])
          get "#{base_url}/#{bike.id}?graduated_notification_remaining=#{graduated_notification.marked_remaining_link_token}"
          expect(assigns(:bike)).to eq bike
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
          get "#{base_url}/#{bike.id}?graduated_notification_remaining=333#{graduated_notification.marked_remaining_link_token}"
          expect(assigns(:bike)).to eq bike
          expect(flash[:error]).to be_present
          bike.reload
          graduated_notification.reload
          expect(bike.graduated?(organization)).to be_truthy
          expect(graduated_notification.status).to eq("active")
          expect(bike.bike_organizations.pluck(:organization_id)).to eq([])
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
    context "setting a bike_sticker" do
      it "gracefully fails if the number is weird" do
        expect(bike.bike_stickers.count).to eq 0
        patch "#{base_url}/#{bike.id}", params: { bike_sticker: "02891426438 " }
        expect(flash[:error]).to be_present
        bike.reload
        expect(bike.bike_stickers.count).to eq 0
      end
    end
    context "setting address for bike" do
      let(:current_user) { FactoryBot.create(:user_confirmed, default_location_registration_address) }
      let(:ownership) { FactoryBot.create(:ownership, user: current_user, creator: current_user) }
      let(:update_attributes) { { street: "10544 82 Ave NW", zipcode: "AB T6E 2A4", city: "Edmonton", country_id: Country.canada.id, state_id: "" } }
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
            patch "#{base_url}/#{bike.id}", params: { bike: update_attributes }
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
      context "bike has location" do
        let(:location_attrs) { { country_id: Country.united_states.id, city: "New York", street: "278 Broadway", zipcode: "10007", latitude: 40.7143528, longitude: -74.0059731, address_set_manually: true } }
        it "marks the bike stolen, doesn't set a location, blanks bike location" do
          bike.update_attributes(location_attrs)
          bike.reload
          expect(bike.address_set_manually).to be_truthy
          expect(bike.stolen?).to be_falsey
          Sidekiq::Worker.clear_all
          Sidekiq::Testing.inline! do
            patch "#{base_url}/#{bike.id}", params: { bike: { stolen: true } }
            expect(flash[:success]).to be_present
          end
          bike.reload
          expect(bike.stolen?).to be_truthy
          expect(bike.to_coordinates.compact).to eq([])
          expect(bike.address_hash).to eq({ country: "US", city: "New York", street: "278 Broadway", zipcode: "10007", state: nil, latitude: nil, longitude: nil }.as_json)

          stolen_record = bike.current_stolen_record
          expect(stolen_record).to be_present
          expect(stolen_record.to_coordinates.compact).to eq([])
          expect(stolen_record.date_stolen).to be_within(5).of Time.current
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
          id: stolen_record.id,
        }
      end

      it "clears the existing alert image" do
        bike.reload
        stolen_record.current_alert_image
        stolen_record.reload
        expect(bike.current_stolen_record).to eq stolen_record
        expect(stolen_record.without_location?).to be_truthy
        og_alert_image_id = stolen_record.alert_image.id
        expect(og_alert_image_id).to be_present
        Sidekiq::Worker.clear_all
        Sidekiq::Testing.inline! do
          patch "#{base_url}/#{bike.id}", params: {
                                      bike: { stolen: "true", stolen_records_attributes: { "0" => stolen_params } },
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
  end
end
