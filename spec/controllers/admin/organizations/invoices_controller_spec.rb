require "spec_helper"

describe Admin::Organizations::InvoicesController, type: :controller do
  let(:organization) { FactoryGirl.create(:organization) }
  let(:invoice) { FactoryGirl.create(:invoice, organization: organization) }
  context "super admin" do
    include_context :logged_in_as_super_admin

    describe "index" do
      it "renders" do
        get :index, organization_id: organization.to_param
        expect(response.status).to eq(200)
        expect(response).to render_template(:index)
      end
    end

    describe "edit" do
      it "renders" do
        get :edit, organization_id: organization.to_param, id: invoice.to_param
        expect(response.status).to eq(200)
        expect(response).to render_template(:edit)
      end
    end

    describe "Paid feature update" do
      # {"paid_feature_ids"=>{"2"=>["0"], "4"=>["0"], "1"=>["0", "1"], "3"=>["0"]},
      # "amount_due"=>"0",
      # "timezone"=>"",
      # "subscription_start_at"=>"2018-09-05T20:00:00"},
    end
  end
end
