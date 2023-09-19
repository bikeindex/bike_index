require "rails_helper"

RSpec.describe Organized::BikesController, type: :controller do
  context "given an authenticated ambassador" do
    include_context :logged_in_as_ambassador
    it "redirects to the organization root path" do
      expect(get(:index, params: {organization_id: organization})).to redirect_to(organization_root_path)
      expect(get(:recoveries, params: {organization_id: organization})).to redirect_to(organization_root_path)
      expect(get(:incompletes, params: {organization_id: organization})).to redirect_to(organization_root_path)
      expect(get(:new, params: {organization_id: organization})).to redirect_to(organization_root_path)
      expect(post(:resend_incomplete_email, params: {organization_id: organization, id: 12})).to redirect_to(organization_root_path)
    end
    describe "multi_serial_search" do
      it "renders" do
        get :multi_serial_search, params: {organization_id: organization.to_param}
        expect(response.status).to eq(200)
        expect(response).to render_template :multi_serial_search
      end
    end
  end

  let(:non_organization_bike) { FactoryBot.create(:bike) }
  before do
    expect(non_organization_bike).to be_present
  end

  context "not organization member" do
    include_context :logged_in_as_user
    let!(:organization) { FactoryBot.create(:organization) }
    it "redirects the user, reassigns passive_organization_id" do
      session[:passive_organization_id] = "0" # Because, who knows! Maybe they don't have org access at some point.
      get :index, params: {organization_id: organization.to_param}
      expect(response.location).to eq my_account_url
      expect(flash[:error]).to be_present
      expect(session[:passive_organization_id]).to eq "0" # sets it to zero so we don't look it up again
    end
    context "admin user" do
      let(:user) { FactoryBot.create(:admin) }
      it "renders, doesn't reassign passive_organization_id" do
        session[:passive_organization_id] = organization.to_param # Admin, so user has access
        get :index, params: {organization_id: organization.to_param}
        expect(response.status).to eq(200)
        expect(response).to render_template :index
        expect(assigns(:current_organization)).to eq organization
        expect(assigns(:page_id)).to eq "organized_bikes_index"
        expect(assigns(:passive_organization)).to eq organization
        expect(session[:passive_organization_id]).to eq organization.id
      end
    end
  end

  context "logged_in_as_organization_admin" do
    include_context :logged_in_as_organization_admin
    describe "index" do
      it "renders" do
        get :index, params: {organization_id: organization.to_param}
        expect(response.status).to eq(200)
        expect(response).to render_template :index
        expect(assigns(:current_organization)).to eq organization
        expect(assigns(:page_id)).to eq "organized_bikes_index"
      end
    end

    describe "new" do
      it "renders" do
        get :new, params: {organization_id: organization.to_param}
        expect(response.status).to eq(200)
        expect(response).to render_template :new
        expect(assigns(:current_organization)).to eq organization
        expect(response.headers["X-Frame-Options"]).to eq "SAMEORIGIN"
      end
    end

    describe "new_iframe" do
      it "renders" do
        get :new_iframe, params: {organization_id: organization.to_param}
        expect(response.status).to eq(200)
        expect(response).to render_template :new_iframe
        expect(assigns(:current_organization)).to eq organization
        expect(response.headers["X-Frame-Options"]).to be_blank
      end
    end

    describe "create" do
      let(:manufacturer) { FactoryBot.create(:manufacturer) }
      let(:color) { FactoryBot.create(:color) }
      let(:attrs) do
        {
          manufacturer_id: manufacturer.id,
          owner_email: "something@sss.com",
          creator_id: 21,
          primary_frame_color_id: color.id,
          creation_organization_id: 9292,
          serial_number: "xcxcxcxcc7xcx"
        }
      end
      it "creates" do
        Sidekiq::Worker.clear_all
        ActionMailer::Base.deliveries = []
        expect(organization.auto_user_id).to_not eq user.id
        expect(UpdateMailchimpDatumWorker).to be_present
        stub_const("UpdateMailchimpDatumWorker::UPDATE_MAILCHIMP", false)
        Sidekiq::Testing.inline! do
          expect {
            post :create, params: {bike: attrs, organization_id: organization.to_param}
          }.to change(Bike, :count).by 1
        end
        expect(response.headers["X-Frame-Options"]).to be_blank

        b_param = BParam.reorder(:created_at).last
        expect(b_param.owner_email).to eq attrs[:owner_email]
        expect(b_param.owner_email).to eq attrs[:owner_email]
        expect(b_param.creation_organization_id).to eq organization.id
        expect(b_param.bike["serial_number"]).to eq attrs[:serial_number]

        bike = b_param.created_bike
        expect(bike.status).to eq "status_with_owner"
        expect(bike.serial_number).to eq attrs[:serial_number]
        expect(bike.id).to eq b_param.created_bike_id
        expect(bike.creator_id).to eq user.id
        expect(bike.organizations.pluck(:id)).to eq([organization.id])
        expect(bike.editable_organizations.pluck(:id)).to eq([organization.id])
        expect(bike.creation_organization_id).to eq organization.id
        expect(bike.manufacturer_id).to eq manufacturer.id
        expect(bike.current_ownership.origin).to eq "organization_form"
        expect(bike.primary_frame_color_id).to eq color.id
        expect(bike.secondary_frame_color_id).to be_blank
        expect(bike.tertiary_frame_color_id).to be_blank

        expect(ActionMailer::Base.deliveries.count).to eq 1
        message = ActionMailer::Base.deliveries.last
        expect(message.to).to eq([attrs[:owner_email]])
        expect(message.subject).to match(/confirm.*registration/i)
      end
    end
  end

  context "logged_in_as_organization_member" do
    include_context :logged_in_as_organization_member
    context "paid organization" do
      let(:enabled_feature_slugs) { %w[bike_search show_recoveries show_partial_registrations bike_stickers impound_bikes] }
      before { organization.update_columns(is_paid: true, enabled_feature_slugs: enabled_feature_slugs) } # Stub organization having organization feature
      describe "index" do
        context "with search_stickers" do
          let!(:bike_with_sticker) { FactoryBot.create(:bike_organized, creation_organization: organization) }
          let!(:bike_sticker) { FactoryBot.create(:bike_sticker_claimed, bike: bike_with_sticker) }
          it "searches for bikes with stickers" do
            expect(bike_with_sticker.bike_sticker?).to be_truthy
            get :index, params: {organization_id: organization.to_param, search_stickers: "none"}
            expect(response.status).to eq(200)
            expect(assigns(:current_organization)).to eq organization
            expect(assigns(:search_stickers)).to eq "none"
            expect(assigns(:bikes).pluck(:id)).to eq([])
            expect(session[:passive_organization_id]).to eq organization.id
          end
        end
        context "without params" do
          it "renders, assigns search_query_present and stolenness all" do
            get :index, params: {organization_id: organization.to_param}
            expect(response.status).to eq(200)
            expect(assigns(:interpreted_params)[:stolenness]).to eq "all"
            expect(assigns(:current_organization)).to eq organization
            expect(assigns(:search_query_present)).to be_falsey
            expect(assigns(:bikes).pluck(:id).include?(non_organization_bike.id)).to be_falsey
          end
        end
      end
      describe "recoveries" do
        let(:bike) { FactoryBot.create(:stolen_bike) }
        let(:bike2) { FactoryBot.create(:stolen_bike) }
        let(:recovered_record) { bike.fetch_current_stolen_record }
        let(:recovered_record2) { bike2.fetch_current_stolen_record }
        let!(:bike_organization) { FactoryBot.create(:bike_organization, bike: bike, organization: organization) }
        let!(:bike_organization2) { FactoryBot.create(:bike_organization, bike: bike2, organization: organization) }
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
          get :recoveries, params: {
            organization_id: organization.to_param,
            period: "custom",
            start_time: Time.parse("2016-01-01").to_i
          }
          expect(response.status).to eq(200)
          expect(assigns(:recoveries).pluck(:id)).to eq([recovered_record.id, recovered_record2.id])
          expect(response).to render_template :recoveries
        end
      end
      describe "incompletes" do
        let(:partial_reg_attrs) do
          {
            manufacturer_id: Manufacturer.other.id,
            primary_frame_color_id: Color.black.id,
            owner_email: "something@stuff.com",
            creation_organization_id: organization.id
          }
        end
        let!(:partial_registration) { BParam.create(params: {bike: partial_reg_attrs}, origin: "embed_partial") }
        it "renders" do
          expect(partial_registration.organization).to eq organization
          get :incompletes, params: {organization_id: organization.to_param}
          expect(response.status).to eq(200)
          expect(response).to render_template :incompletes
          expect(assigns(:b_params).pluck(:id)).to eq([partial_registration.id])
        end
        context "suborganization incomplete" do
          let(:organization_child) { FactoryBot.create(:organization_child, parent_organization: organization) }
          let!(:partial_registration) { BParam.create(params: {bike: partial_reg_attrs.merge(creation_organization_id: organization_child.id)}, origin: "embed_partial") }
          it "renders" do
            organization.save
            organization.update_columns(is_paid: true, enabled_feature_slugs: enabled_feature_slugs) # Continue organization feature stubbing
            expect(partial_registration.organization).to eq organization_child

            get :incompletes, params: {organization_id: organization.to_param}

            expect(response.status).to eq(200)
            expect(response).to render_template :incompletes
            expect(assigns(:b_params).pluck(:id)).to eq([partial_registration.id])
          end
        end
      end
      describe "multi_serial_search" do
        it "renders" do
          get :multi_serial_search, params: {organization_id: organization.to_param}
          expect(response.status).to eq(200)
          expect(response).to render_template :multi_serial_search
        end
      end
    end
    context "unpaid organization" do
      before do
        expect(organization.is_paid).to be_falsey
      end
      describe "index" do
        it "renders without search" do
          expect(Bike).to_not receive(:search)
          get :index, params: {organization_id: organization.to_param}
          expect(response.status).to eq(200)
          expect(response).to render_template :index
          expect(assigns(:current_organization)).to eq organization
          expect(assigns(:bikes).pluck(:id).include?(non_organization_bike.id)).to be_falsey
        end
      end
      describe "recoveries" do
        it "redirects recoveries" do
          get :recoveries, params: {organization_id: organization.to_param}
          expect(response.location).to match(organization_bikes_path(organization_id: organization.to_param))
        end
      end
      describe "incompletes" do
        it "redirects incompletes" do
          get :incompletes, params: {organization_id: organization.to_param}
          expect(response.location).to match(organization_bikes_path(organization_id: organization.to_param))
        end
      end
    end

    describe "new" do
      it "renders" do
        get :new, params: {organization_id: organization.to_param}
        expect(response.status).to eq(200)
        expect(response).to render_template :new
        expect(assigns(:current_organization)).to eq organization
      end
    end
  end
end
