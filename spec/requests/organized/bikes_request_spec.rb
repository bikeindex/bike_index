require "rails_helper"

RSpec.describe Organized::BikesController, type: :request do
  let(:base_url) { "/o/#{current_organization.to_param}/bikes" }
  include_context :request_spec_logged_in_as_organization_user
  let(:enabled_feature_slugs) { %w[bike_search show_recoveries show_partial_registrations bike_stickers impound_bikes] }
  let(:current_organization) { FactoryBot.create(:organization_with_organization_features, enabled_feature_slugs: enabled_feature_slugs) }

  describe "index" do
    # NOTE: Additional index tests in controller spec because of session
    let(:query_params) do
      {
        query: "1",
        manufacturer: "2",
        colors: %w[3 4],
        location: "5",
        distance: "6",
        serial: "9",
        query_items: %w[7 8],
        stolenness: "stolen"
      }.as_json
    end
    let!(:non_organization_bike) { FactoryBot.create(:bike) }
    let!(:bike) { FactoryBot.create(:bike_organized, creation_organization: current_organization) }
    it "sends all the params and renders search template to organization_bikes" do
      get base_url, params: query_params
      expect(response.status).to eq(200)
      expect(assigns(:current_organization)).to eq current_organization
      expect(assigns(:search_query_present)).to be_truthy
      expect(assigns(:bikes).pluck(:id)).to eq([])
      expect(assigns(:search_stickers)).to eq false
      # create_export fails if the org doesn't have have csv_exports
      expect {
        get base_url, params: query_params.merge(create_export: true)
      }.to_not change(Export, :count)
      # Search without_street to verify that scope works

      get base_url, params: {search_address: "without_street"}
      expect(response.status).to eq(200)
      expect(assigns(:search_query_present)).to be_falsey
      expect(assigns(:bikes).pluck(:id)).to eq([bike.id])
    end
    context "member_no_bike_edit" do
      let(:current_user) { FactoryBot.create(:organization_user, organization: current_organization, role: "member_no_bike_edit") }
      it "allows viewing" do
        expect(current_user.reload.organization_roles.first.role).to eq "member_no_bike_edit"
        get base_url, params: query_params
        expect(response.status).to eq(200)
        expect(assigns(:current_organization)).to eq current_organization
        expect(assigns(:search_query_present)).to be_truthy
        expect(assigns(:bikes).pluck(:id)).to eq([])
      end
    end
    describe "create_export" do
      let(:enabled_feature_slugs) { %w[bike_search show_recoveries show_partial_registrations bike_stickers impound_bikes csv_exports] }
      let(:target_params) do
        {
          organization_id: current_organization.id,
          custom_bike_ids: "#{bike.id}_#{bike2.id}",
          only_custom_bike_ids: true
        }
      end
      let!(:bike2) { FactoryBot.create(:bike_organized, creation_organization: current_organization, manufacturer: bike.manufacturer) }
      it "creates export", :flaky do
        expect {
          get base_url, params: {manufacturer: bike.manufacturer.id, create_export: true}
        }.to change(Export, :count).by 0
        expect(flash).to be_blank
        redirected_to = response.redirect_url
        expect(redirected_to.gsub(/custom_bike_ids=\d+_\d+&/, "")).to eq new_organization_export_url(target_params.except(:custom_bike_ids))
        custom_bike_ids = redirected_to.match(/custom_bike_ids=(\d+)_(\d+)&/)[1, 2]
        expect(custom_bike_ids).to match_array([bike.id, bike2.id].map(&:to_s))

        expect {
          get base_url, params: {stolenness: "impounded", create_export: true}
        }.to change(Export, :count).by 0
        expect(flash[:error]).to match(/no match/)
        expect(response).to redirect_to(new_organization_export_url(organization_id: current_organization.id, only_custom_bike_ids: true, custom_bike_ids: ""))
      end
      context "without search params" do
        let(:params_blank) do
          {
            period: nil, organization_id: current_organization.id, search_email: nil, serial: nil,
            end_time: nil, start_time: nil, user_id: nil, search_bike_id: nil, render_chart: false,
            search_marketplace_listing_id: nil, search_status: nil, search_kind: nil, search_ignored: nil,
            stolenness: "all", search_stickers: nil, search_address: nil, search_secondary: nil,
            sort: "id", sort_direction: "desc", create_export: true
          }
        end
        it "redirects to export new" do
          expect {
            get base_url, params: params_blank
          }.to change(Export, :count).by 0
          expect(flash).to be_blank
          expect(response).to redirect_to new_organization_export_url(organization_id: current_organization.id)

          expect {
            get base_url, params: params_blank.merge(period: "year")
          }.to change(Export, :count).by 0
          expect(flash).to be_blank

          redirected_to = response.redirect_url
          expect(redirected_to.gsub(/end_at=\d+&?/, "").gsub(/start_at=\d+&?/, "").gsub(/\?\z/, ""))
            .to eq new_organization_export_url(organization_id: current_organization.id)

          start_at = redirected_to.match(/start_at=(\d+)/)[1]
          expect(start_at.to_i).to be_within(5).of((Time.current.beginning_of_day - 1.year).to_i)

          end_at = redirected_to.match(/end_at=(\d+)/)[1]
          expect(end_at.to_i).to be_within(5).of(Time.current.to_i)
        end
      end
      context "directly create export", :flaky do
        it "directly creates" do
          Sidekiq::Job.clear_all
          expect {
            get base_url, params: {manufacturer: bike.manufacturer.id, create_export: true, directly_create_export: 1}
          }.to change(Export, :count).by 1
          expect(flash[:info]).to be_present
          export = Export.last
          expect(export.organization_id).to eq current_organization.id
          expect(export.kind).to eq "organization"
          expect(export.custom_bike_ids).to match_array([bike.id, bike2.id])
          expect(export.user_id).to eq current_user.id
          expect(response).to redirect_to(organization_export_path(export, organization_id: current_organization.id))
          expect(OrganizationExportJob.jobs.count).to eq 1
        end
      end
    end
    context "with search_stickers" do
      let!(:bike_with_sticker) { FactoryBot.create(:bike_organized, creation_organization: current_organization) }
      let!(:bike_sticker) { FactoryBot.create(:bike_sticker_claimed, organization: current_organization, bike: bike_with_sticker) }
      let!(:non_organization_bike) { FactoryBot.create(:bike) }
      let!(:bike_sticker_2) { FactoryBot.create(:bike_sticker_claimed, organization: current_organization, bike: non_organization_bike) }
      it "searches for bikes with stickers" do
        expect(bike_with_sticker.reload.bike_sticker?).to be_truthy
        expect(current_organization.reload.paid?).to be_truthy
        get base_url, params: {search_stickers: "none"}
        expect(response.status).to eq(200)
        expect(assigns(:current_organization)).to eq current_organization
        expect(assigns(:search_stickers)).to eq "none"
        expect(assigns(:bikes).pluck(:id)).to eq([bike.id])
        expect(session[:passive_organization_id]).to eq current_organization.id

        # And searching without params returns expected result
        get base_url
        expect(response.status).to eq(200)
        expect(assigns(:bikes).pluck(:id)).to match_array([bike.id, bike_with_sticker.id])
        expect(assigns(:search_query_present)).to be_falsey
        expect(assigns(:search_stickers)).to eq false
        expect(assigns(:interpreted_params)[:stolenness]).to eq "all"
        expect(assigns(:interpreted_params)).to match_hash_indifferently({stolenness: "all"})
      end
    end

    context "unpaid organization" do
      let(:current_organization) { FactoryBot.create(:organization) }

      it "renders without search" do
        expect(current_organization.reload.paid?).to be_falsey
        expect(Bike).to_not receive(:search)
        get base_url
        expect(response.status).to eq(200)
        expect(response).to render_template :index
        expect(assigns(:current_organization)).to eq current_organization
        expect(assigns(:bikes).pluck(:id).include?(non_organization_bike.id)).to be_falsey
      end
    end
  end

  describe "new" do
    it "redirects" do
      get "#{base_url}/new"
      expect(response).to redirect_to organization_manage_path(current_organization)
      expect(flash[:error]).to match(/email/i)
    end
    context "with auto_user present" do
      let(:current_organization) { FactoryBot.create(:organization_with_organization_features, :with_auto_user, enabled_feature_slugs: enabled_feature_slugs) }
      it "renders" do
        get "#{base_url}/new"
        expect(response.status).to eq(200)
        expect(assigns(:unregistered_parking_notification)).to be_falsey
        expect(response).to render_template(:new)
        expect(response.headers["X-Frame-Options"]).to eq "SAMEORIGIN"
      end
      context "parking_notification" do
        it "renders with unregistered_parking_notification" do
          get "#{base_url}/new", params: {parking_notification: 1}
          expect(response.status).to eq(200)
          expect(assigns(:unregistered_parking_notification)).to be_falsey
          expect(response).to render_template(:new)
        end
        context "with feature" do
          let(:enabled_feature_slugs) { ["parking_notifications"] }
          it "renders with unregistered_parking_notification" do
            get "#{base_url}/new", params: {parking_notification: 1}
            expect(response.status).to eq(200)
            expect(assigns(:unregistered_parking_notification)).to be_truthy
            expect(response).to render_template(:new)
          end
        end
      end
    end
  end

  describe "new_iframe" do
    it "renders" do
      get "#{base_url}/new_iframe", params: {parking_notification: 1}
      expect(response.status).to eq(200)
      expect(response).to render_template(:new_iframe)
      expect(response.headers["X-Frame-Options"]).to be_blank
    end
    context "without current_organization" do
      include_context :request_spec_logged_in_as_user
      it "redirects (unlike normal iframe)" do
        expect(current_user.organizations).to eq([])
        get "#{base_url}/new_iframe", params: {parking_notification: 1}
        expect(response).to redirect_to user_root_url
        expect(flash[:error]).to be_present
      end
    end
  end

  describe "create" do
    before { current_organization.update(auto_user: auto_user) }
    let(:auto_user) { current_user }
    let(:b_param) { BParam.create(creator_id: current_organization.auto_user.id, params: {creation_organization_id: current_organization.id, embeded: true}) }
    let(:manufacturer) { FactoryBot.create(:manufacturer) }
    let(:color) { Color.black }
    let!(:state) { FactoryBot.create(:state_new_york) }
    let(:testable_bike_params) { bike_params.except(:serial_unknown, :b_param_id_token, :cycle_type_slug, :accuracy, :origin) }
    context "with parking_notification" do
      let(:enabled_feature_slugs) { %w[parking_notifications impound_bikes] }
      let(:state) { FactoryBot.create(:state_new_york) }

      let(:parking_notification) do
        {
          kind: "parked_incorrectly_notification",
          internal_notes: "some details about the abandoned thing",
          use_entered_address: "false",
          latitude: default_location[:latitude],
          longitude: default_location[:longitude],
          message: "Some message to the user",
          street: "",
          city: "",
          accuracy: "14.2",
          zipcode: "10007",
          state_id: state.id.to_s,
          country_id: Country.united_states.id
        }
      end
      let(:bike_params) do
        {
          serial_number: "",
          b_param_id_token: b_param.id_token,
          cycle_type_slug: " Tricycle ",
          manufacturer_id: manufacturer.id,
          primary_frame_color_id: color.id,
          latitude: default_location[:latitude],
          longitude: default_location[:longitude]
        }
      end
      let(:test_photo) { Rack::Test::UploadedFile.new(File.open(File.join(Rails.root, "spec", "fixtures", "bike.jpg"))) }
      it "creates along with parking_notification and photo" do
        current_organization.reload
        expect(current_organization.auto_user).to eq current_user
        expect(current_organization.public_impound_bikes?).to be_falsey
        ActionMailer::Base.deliveries = []
        Sidekiq::Job.clear_all
        Sidekiq::Testing.inline! do
          expect {
            post base_url, params: {bike: bike_params.merge(image: test_photo), parking_notification: parking_notification}
            expect(flash[:success]).to match(/tricycle/i)
            expect(response).to redirect_to new_iframe_organization_bikes_path(organization_id: current_organization.to_param)
            expect(response.headers["X-Frame-Options"]).to be_blank
          }.to change(Ownership, :count).by 1
          expect(ActionMailer::Base.deliveries.count).to eq 0
        end
        # Have to do after, because inline sidekiq ignores delays and created_bike isn't present when it's run
        Images::AssociatorJob.new.perform

        b_param.reload
        expect(b_param.creation_organization).to eq current_organization
        expect(b_param.unregistered_parking_notification?).to be_truthy
        expect(b_param.origin).to eq "organization_form"
        expect(b_param.image_processed).to be_truthy
        expect(b_param.image).to be_present
        expect(b_param.status).to eq "unregistered_parking_notification"

        bike = b_param.created_bike
        expect(bike.made_without_serial?).to be_falsey
        expect(bike.serial_unknown?).to be_truthy
        expect(bike.cycle_type).to eq "tricycle"
        expect(bike.creation_organization).to eq current_organization
        expect(bike.status).to eq "unregistered_parking_notification"
        expect(bike.user_hidden).to be_truthy
        expect(bike.user_hidden).to be_truthy
        expect(bike.creator_unregistered_parking_notification?).to be_truthy
        expect(bike.public_images.count).to eq 1
        expect(bike.bike_organizations.first.can_not_edit_claimed).to be_falsey
        expect(bike).to match_hash_indifferently testable_bike_params.except(:serial_number)

        ownership = bike.ownerships.first
        expect(ownership.send_email).to be_falsey
        expect(ownership.owner_email).to eq auto_user.email

        ownership = bike.current_ownership
        expect(ownership.organization).to eq current_organization
        expect(ownership.creator).to eq bike.creator
        expect(ownership.status).to eq "unregistered_parking_notification"
        expect(ownership.origin).to eq "creator_unregistered_parking_notification"

        expect(bike.parking_notifications.count).to eq 1
        parking_notification = bike.parking_notifications.first
        expect(parking_notification.organization).to eq current_organization
        expect(parking_notification.kind).to eq "parked_incorrectly_notification"
        expect(parking_notification.internal_notes).to eq "some details about the abandoned thing"
        expect(parking_notification.message).to eq "Some message to the user"
        expect(parking_notification.latitude).to eq default_location[:latitude]
        expect(parking_notification.longitude).to eq default_location[:longitude]
        expect(parking_notification.location_from_address).to be_falsey
        expect(parking_notification.street).to eq "278 Broadway"
        expect(parking_notification.city).to eq "New York"
        expect(parking_notification.accuracy).to eq 14.2
        expect(parking_notification.retrieval_link_token).to be_blank
      end
      context "failure" do
        it "rerenders, adds errors" do
          expect(ParkingNotification.count).to eq 0
          expect {
            post base_url, params: {bike: bike_params.except(:manufacturer_id), parking_notification: parking_notification}
          }.to change(Bike, :count).by 0
          expect(flash[:error]).to match(/manufacturer/i)
          expect(b_param.reload.bike_errors.to_s).to match(/manufacturer/i)
          expect(assigns(:bike)).to match_hash_indifferently testable_bike_params.except(:manufacturer_id, :serial_number)
          expect(ParkingNotification.count).to eq 0
        end
      end

      context "different auto_user, impound_notification" do
        let!(:auto_user) { FactoryBot.create(:organization_user, organization: current_organization) }
        let!(:impound_configuration) { FactoryBot.create(:impound_configuration, organization_id: current_organization.id, public_view: true) }
        let(:parking_notification_abandoned) do
          parking_notification.merge(use_entered_address: "1",
            kind: "impound_notification",
            street: "10544 82 Ave NW",
            city: "Edmonton",
            country_id: Country.canada.id,
            zipcode: "T6E 2A4",
            internal_notes: "Impounded it!")
        end
        include_context :geocoder_real
        it "creates a new ownership, parking_notification, impound_record" do
          current_organization.reload
          expect(current_organization.auto_user).to eq auto_user
          expect(current_organization.public_impound_bikes?).to be_truthy
          expect(parking_notification_abandoned[:state_id]).to be_present # Test that we're blanking the state
          VCR.use_cassette("organized_bikes_controller-create-impound-record-edmonton", match_requests_on: [:path]) do
            Sidekiq::Testing.inline! do
              ActionMailer::Base.deliveries = []
              expect {
                post base_url, params: {bike: bike_params, parking_notification: parking_notification_abandoned}
                expect(flash[:success]).to match(/tricycle/i)
                expect(response).to redirect_to new_iframe_organization_bikes_path(organization_id: current_organization.to_param)
              }.to change(Ownership, :count).by 1
              expect(ActionMailer::Base.deliveries.count).to eq 0
            end
          end

          b_param.reload
          expect(b_param.creation_organization).to eq current_organization
          expect(b_param.unregistered_parking_notification?).to be_truthy
          expect(b_param.origin).to eq "organization_form"
          expect(b_param.image).to_not be_present

          bike = Bike.unscoped.find(b_param.created_bike_id)
          expect(b_param.created_bike).to eq bike
          expect(bike.made_without_serial?).to be_falsey
          expect(bike.serial_unknown?).to be_truthy
          expect(bike.cycle_type).to eq "tricycle"
          expect(bike.creation_organization).to eq current_organization
          expect(bike.user_hidden).to be_falsey
          expect(bike.status).to eq "status_impounded"
          expect(bike.creator_unregistered_parking_notification?).to be_truthy
          expect(bike).to match_hash_indifferently testable_bike_params.except(:serial_number, :latitude, :longitude)

          ownership = bike.ownerships.first
          expect(ownership.send_email).to be_falsey
          # Maybe make this work?
          # expect(ownership.claimed?).to be_truthy
          expect(ownership.owner_email).to eq auto_user.email

          ownership = bike.current_ownership
          expect(ownership.organization).to eq current_organization
          expect(ownership.creator).to eq bike.creator
          expect(ownership.status).to eq "unregistered_parking_notification"
          expect(ownership.origin).to eq "creator_unregistered_parking_notification"

          expect(ParkingNotification.where(bike_id: bike.id).count).to eq 1
          parking_notification = ParkingNotification.where(bike_id: bike.id).first
          expect(bike.parking_notifications.count).to eq 1
          expect(bike.parking_notifications.first.id).to eq parking_notification.id
          expect(parking_notification.organization).to eq current_organization
          expect(parking_notification.kind).to eq "impound_notification"
          expect(parking_notification.internal_notes).to eq "Impounded it!"
          expect(parking_notification.message).to eq "Some message to the user"
          expect(parking_notification.current?).to be_falsey
          expect(parking_notification.impounded?).to be_truthy
          expect(parking_notification.location_from_address).to be_truthy
          expect(parking_notification.street).to eq "10544 82 Ave NW"
          expect(parking_notification.city).to eq "Edmonton"
          expect(parking_notification.state_id).to be_blank
          expect(parking_notification.zipcode).to eq "T6E 2A4"
          expect(parking_notification.latitude).to eq 53.5183943
          expect(parking_notification.longitude).to eq(-113.5023587)

          impound_record = bike.current_impound_record
          expect(impound_record.parking_notification).to eq parking_notification
          expect(impound_record.organization).to eq current_organization
          expect(impound_record.current?).to be_truthy
          expect(impound_record.unregistered_bike).to be_truthy
        end
      end
    end
  end

  describe "recoveries" do
    let(:bike) { FactoryBot.create(:stolen_bike) }
    let(:bike2) { FactoryBot.create(:stolen_bike) }
    let(:recovered_record) { bike.fetch_current_stolen_record }
    let(:recovered_record2) { bike2.fetch_current_stolen_record }
    let!(:bike_organization) { FactoryBot.create(:bike_organization, bike: bike, organization: current_organization) }
    let!(:bike_organization2) { FactoryBot.create(:bike_organization, bike: bike2, organization: current_organization) }
    let(:date) { "2016-01-10 13:59:59" }
    let(:recovery_information) do
      {
        recovered_description: "recovered it on a special corner",
        index_helped_recovery: true,
        can_share_recovery: true,
        recovered_at: "2016-01-10 13:59:59"
      }
    end
    before do
      recovered_record.add_recovery_information
      recovered_record2.add_recovery_information(recovery_information)
    end
    it "renders, assigns search_query_present and stolenness all" do
      expect(recovered_record2.recovered_at.to_date).to eq Date.parse("2016-01-10")
      get "#{base_url}/recoveries", params: {
        period: "custom",
        start_time: Time.parse("2016-01-01").to_i
      }
      expect(response.status).to eq(200)
      expect(assigns(:recoveries).pluck(:id)).to eq([recovered_record.id, recovered_record2.id])
      expect(response).to render_template :recoveries
    end
    context "unpaid organization" do
      let(:current_organization) { FactoryBot.create(:organization) }
      it "redirects" do
        expect(current_organization.reload.paid?).to be_falsey
        get "#{base_url}/recoveries"
        expect(response.location).to match(organization_bikes_path(organization_id: current_organization.to_param))
      end
    end
  end

  describe "incompletes" do
    let(:partial_reg_attrs) do
      {
        manufacturer_id: Manufacturer.other.id,
        primary_frame_color_id: Color.black.id,
        owner_email: "something@stuff.com",
        creation_organization_id: current_organization.id
      }
    end
    let!(:partial_registration) { BParam.create(params: {bike: partial_reg_attrs}, origin: "embed_partial") }
    it "renders" do
      expect(partial_registration.organization).to eq current_organization
      get "#{base_url}/incompletes"
      expect(response.status).to eq(200)
      expect(response).to render_template :incompletes
      expect(assigns(:b_params).pluck(:id)).to eq([partial_registration.id])
    end
    context "sortable" do
      let(:motorized_params) { partial_reg_attrs.merge(cycle_type: "tandem", propulsion_type_slug: "pedal-assist") }
      let!(:b_param_motorized) { FactoryBot.create(:b_param, params: {bike: motorized_params}) }
      it "renders" do
        expect(b_param_motorized.reload.motorized?).to be_truthy
        expect(b_param_motorized.cycle_type).to eq "tandem"
        expect(partial_registration.organization).to eq current_organization
        get "#{base_url}/incompletes"
        expect(assigns(:sort_column)).to eq "id"
        expect(response.status).to eq(200)
        expect(response).to render_template :incompletes
        expect(assigns(:b_params).pluck(:id)).to eq([partial_registration.id])

        get "#{base_url}/incompletes", params: {sort: "cycle_type"}
        expect(response.status).to eq(200)
        expect(response).to render_template :incompletes
        expect(assigns(:sort_column)).to eq "cycle_type"

        get "#{base_url}/incompletes", params: {sort: "motorized"}
        expect(response.status).to eq(200)
        expect(response).to render_template :incompletes
        expect(assigns(:sort_column)).to eq "motorized"
      end
    end
    context "suborganization incomplete" do
      let(:organization_child) { FactoryBot.create(:organization_child, parent_organization: current_organization) }
      let!(:partial_registration) { BParam.create(params: {bike: partial_reg_attrs.merge(creation_organization_id: organization_child.id)}, origin: "embed_partial") }
      it "renders" do
        current_organization.save # Have to resave organization because of child relationship, and re-stub
        current_organization.update_columns(is_paid: true, enabled_feature_slugs: enabled_feature_slugs)
        expect(organization_child.reload.paid?).to be_truthy

        expect(partial_registration.organization).to eq organization_child
        get "#{base_url}/incompletes"
        expect(response.status).to eq(200)
        expect(response).to render_template :incompletes
        expect(assigns(:b_params).pluck(:id)).to eq([partial_registration.id])
      end
    end

    context "unpaid organization" do
      let(:current_organization) { FactoryBot.create(:organization) }

      it "redirects" do
        expect(current_organization.reload.paid?).to be_falsey
        get "#{base_url}/incompletes"
        expect(response.location).to match(organization_bikes_path(organization_id: current_organization.to_param))
      end
    end
  end

  describe "multi_serial_search" do
    it "renders" do
      get "#{base_url}/multi_serial_search"
      expect(response.status).to eq(200)
      expect(response).to render_template :multi_serial_search
    end
  end
end
