require "spec_helper"

describe Organized::BikesController, type: :controller do
  let(:non_organization_bike) { FactoryBot.create(:bike) }
  before do
    expect(non_organization_bike).to be_present
  end

  context "not organization member" do
    include_context :logged_in_as_user
    let!(:organization) { FactoryBot.create(:organization) }
    it "redirects the user, reassigns passive_organization_id" do
      session[:passive_organization_id] = organization.id # Even though the user isn't part of the organization
      get :index, organization_id: organization.to_param
      expect(response.location).to eq user_home_url
      expect(flash[:error]).to be_present
      expect(session[:passive_organization_id]).to eq "0" # sets it to zero so we don't look it up again
    end
    context "admin user" do
      let(:user) { FactoryBot.create(:admin) }
      it "renders, doesn't reassign passive_organization_id" do
        session[:passive_organization_id] = organization.to_param # Admin, so user has access
        get :index, organization_id: organization.to_param
        expect(response.status).to eq(200)
        expect(response).to render_template :index
        expect(response).to render_with_layout("application_revised")
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
        get :index, organization_id: organization.to_param
        expect(response.status).to eq(200)
        expect(response).to render_template :index
        expect(response).to render_with_layout("application_revised")
        expect(assigns(:current_organization)).to eq organization
        expect(assigns(:page_id)).to eq "organized_bikes_index"
      end
    end

    describe "new" do
      it "renders" do
        get :new, organization_id: organization.to_param
        expect(response.status).to eq(200)
        expect(response).to render_template :new
        expect(response).to render_with_layout("application_revised")
        expect(assigns(:current_organization)).to eq organization
      end
    end
  end

  context "logged_in_as_organization_member" do
    include_context :logged_in_as_organization_member
    context "paid organization" do
      before { organization.update_columns(is_paid: true, paid_feature_slugs: %w[bike_search show_recoveries show_partial_registrations bike_codes]) } # Stub organization having paid feature
      describe "index" do
        context "with params" do
          let(:query_params) do
            {
              query: "1",
              manufacturer: "2",
              colors: %w(3 4),
              location: "5",
              distance: "6",
              serial: "9",
              query_items: %w(7 8),
              stolenness: "stolen",
            }.as_json
          end
          let(:organization_bikes) { organization.bikes }
          it "sends all the params and renders search template to organization_bikes" do
            session[:passive_organization_id] = "0" # Because, who knows! Maybe they don't have org access at some point.
            get :index, query_params.merge(organization_id: organization.to_param)
            expect(response.status).to eq(200)
            expect(assigns(:current_organization)).to eq organization
            expect(assigns(:search_query_present)).to be_truthy
            expect(assigns(:bikes).pluck(:id).include?(non_organization_bike.id)).to be_falsey
            expect(session[:passive_organization_id]).to eq organization.id
          end
        end
        context "with search_stickers" do
          let!(:bike_with_sticker) { FactoryBot.create(:organization_bike, organization: organization) }
          let!(:bike_code) { FactoryBot.create(:bike_code_claimed, bike: bike_with_sticker) }
          it "searches for bikes with stickers" do
            expect(bike_with_sticker.bike_code?).to be_truthy
            expect(organization_bikes.pluck(:id).count).to be > 1
            get :index, { organization_id: organization.to_param, search_stickers: "with" }
            expect(response.status).to eq(200)
            expect(assigns(:current_organization)).to eq organization
            expect(assigns(:search_query_present)).to be_truthy
            expect(assigns(:bikes).pluck(:id)).to eq([bike_with_sticker.id])
            expect(session[:passive_organization_id]).to eq organization.id
          end
        end
        context "without params" do
          it "renders, assigns search_query_present and stolenness all" do
            get :index, organization_id: organization.to_param
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
        let(:recovered_record) { bike.find_current_stolen_record }
        let(:recovered_record2) { bike2.find_current_stolen_record }
        let!(:bike_organization) { FactoryBot.create(:bike_organization, bike: bike, organization: organization) }
        let!(:bike_organization2) { FactoryBot.create(:bike_organization, bike: bike2, organization: organization) }
        let(:date) { "2016-01-10 13:59:59" }
        let(:recovery_information) do
          {
            recovered_description: "recovered it on a special corner",
            index_helped_recovery: true,
            can_share_recovery: true,
            date_recovered: "2016-01-10 13:59:59",
          }
        end
        before do
          recovered_record.add_recovery_information
          recovered_record2.add_recovery_information(recovery_information)
        end
        it "renders, assigns search_query_present and stolenness all" do
          expect(recovered_record2.date_recovered.to_date).to eq Date.parse("2016-01-10")
          get :recoveries, organization_id: organization.to_param
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
            creation_organization_id: organization.id,
          }
        end
        let!(:partial_registration) { BParam.create(params: { bike: partial_reg_attrs }, origin: "embed_partial") }
        it "renders" do
          expect(partial_registration.organization).to eq organization
          get :incompletes, organization_id: organization.to_param
          expect(response.status).to eq(200)
          expect(response).to render_template :incompletes
          expect(assigns(:b_params).pluck(:id)).to eq([partial_registration.id])
        end
        context "suborganization incomplete" do
          let(:organization_child) { FactoryBot.create(:organization_child, parent_organization: organization) }
          let!(:partial_registration) { BParam.create(params: { bike: partial_reg_attrs.merge(creation_organization_id: organization_child.id) }, origin: "embed_partial") }
          it "renders" do
            expect(partial_registration.organization).to eq organization_child
            get :incompletes, organization_id: organization.to_param
            expect(response.status).to eq(200)
            expect(response).to render_template :incompletes
            expect(assigns(:b_params).pluck(:id)).to eq([partial_registration.id])
          end
        end
      end
      describe "multi_serial_search" do
        it "renders" do
          get :multi_serial_search, organization_id: organization.to_param
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
          get :index, organization_id: organization.to_param
          expect(response.status).to eq(200)
          expect(response).to render_template :index
          expect(response).to render_with_layout("application_revised")
          expect(assigns(:current_organization)).to eq organization
          expect(assigns(:bikes).pluck(:id).include?(non_organization_bike.id)).to be_falsey
        end
      end
      describe "recoveries" do
        it "redirects recoveries" do
          get :recoveries, organization_id: organization.to_param
          expect(response.location).to match(organization_bikes_path(organization_id: organization.to_param))
        end
      end
      describe "incompletes" do
        it "redirects incompletes" do
          get :incompletes, organization_id: organization.to_param
          expect(response.location).to match(organization_bikes_path(organization_id: organization.to_param))
        end
      end
    end

    describe "new" do
      it "renders" do
        get :new, organization_id: organization.to_param
        expect(response.status).to eq(200)
        expect(response).to render_template :new
        expect(response).to render_with_layout("application_revised")
        expect(assigns(:current_organization)).to eq organization
      end
    end
  end
end
