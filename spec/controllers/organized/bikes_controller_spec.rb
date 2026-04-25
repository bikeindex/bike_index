require "rails_helper"

# Need controller specs to test setting session
#
# PUT ALL TESTS IN Request spec !
#
RSpec.describe Organized::BikesController, type: :controller do
  context "given an authenticated ambassador" do
    include_context :logged_in_as_ambassador
    it "redirects to the organization root path" do
      expect(get(:recoveries, params: {organization_id: organization})).to redirect_to(organization_root_path)
      expect(get(:incompletes, params: {organization_id: organization})).to redirect_to(organization_root_path)
      expect(get(:new, params: {organization_id: organization})).to redirect_to(organization_root_path)
      expect(post(:resend_incomplete_email, params: {organization_id: organization, id: 12})).to redirect_to(organization_root_path)
    end
  end

  let(:non_organization_bike) { FactoryBot.create(:bike) }
  before do
    expect(non_organization_bike).to be_present
  end

  context "logged_in_as_organization_admin" do
    include_context :logged_in_as_organization_admin

    describe "new" do
      let(:organization) { FactoryBot.create(:organization, :with_auto_user) }

      it "renders" do
        get :new, params: {organization_id: organization.to_param}
        expect(response.status).to eq(200)
        expect(response).to render_template :new
        expect(assigns(:current_organization)).to eq organization
      end
    end

    describe "new_iframe" do
      it "renders" do
        get :new_iframe, params: {organization_id: organization.to_param}
        expect(response.status).to eq(200)
        expect(response).to render_template :new_iframe
        expect(assigns(:current_organization)).to eq organization
        expect(assigns(:bike)&.creation_organization_id).to eq organization.id
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
        Sidekiq::Job.clear_all
        ActionMailer::Base.deliveries = []
        expect(organization.auto_user_id).to_not eq user.id
        expect(UpdateMailchimpDatumJob).to be_present
        stub_const("UpdateMailchimpDatumJob::UPDATE_MAILCHIMP", false)
        Sidekiq::Testing.inline! do
          expect {
            post :create, params: {bike: attrs, organization_id: organization.to_param}
          }.to change(Bike, :count).by 1
        end

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
        expect(bike.send(:editable_organization_ids)).to eq([organization.id])
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
end
