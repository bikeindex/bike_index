require "spec_helper"

describe Admin::Organizations::InvoicesController, type: :controller do
  let(:organization) { FactoryBot.create(:organization) }
  let(:invoice) { FactoryBot.create(:invoice, organization: organization) }
  let(:paid_feature1) { FactoryBot.create(:paid_feature, feature_slugs: ["abandoned_bike_messages"]) }
  let(:paid_feature2) { FactoryBot.create(:paid_feature) }
  let(:params) do
    {
      paid_feature_ids: [paid_feature1.id, paid_feature2.id].join(","),
      amount_due: "1220",
      timezone: "EST",
      start_at: "2018-09-05T23:00:00",
      notes: "some cool note about when something was paid",
    }
  end
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

    describe "create" do
      it "creates" do
        expect do
          post :create, organization_id: organization.to_param, invoice: params
        end.to change(Invoice, :count).by 1
        # TODO: Rails 5 update
        organization.update_attributes(updated_at: Time.now)
        invoice = organization.invoices.last
        expect(invoice.active?).to be_falsey
        expect(organization.is_paid).to be_falsey
        expect(organization.paid_feature_slugs).to eq([])
        expect(invoice.paid_feature_ids).to match_array([paid_feature1.id, paid_feature2.id])
        expect(invoice.amount_due).to eq 1220
        # TimeParser isn't storing records perfectly - for now, just ignoring since fix can be separate
        expect(invoice.subscription_start_at.to_i).to be_within(1.day).of 1536202800
        expect(invoice.notes).to eq params[:notes]
      end
      context "with amount_do 0" do
        it "makes the invoice active" do
          expect do
            post :create, organization_id: organization.to_param, invoice: params.merge(amount_due: "0", end_at: "2020-09-05T23:00:00")
          end.to change(Invoice, :count).by 1
          # TODO: Rails 5 update
          organization.update_attributes(updated_at: Time.now)
          invoice = organization.invoices.last
          expect(invoice.active?).to be_truthy
          expect(organization.is_paid).to be_truthy
          expect(organization.paid_feature_slugs).to eq(["abandoned_bike_messages"])
          expect(invoice.paid_feature_ids).to match_array([paid_feature1.id, paid_feature2.id])
          expect(invoice.amount_due).to eq 0
          # TimeParser isn't storing records perfectly - for now, just ignoring since fix can be separate
          expect(invoice.subscription_start_at.to_i).to be_within(1.day).of 1536202800
          expect(invoice.subscription_end_at.to_i).to be_within(1.day).of 1536202800 + 2.years
          expect(invoice.notes).to eq params[:notes]
        end
      end
    end

    describe "update" do
      let(:paid_feature3) { FactoryBot.create(:paid_feature) }
      let(:invoice) { FactoryBot.create(:invoice, organization: organization, amount_due: 10) }
      it "creates" do
        invoice.paid_feature_ids = [paid_feature3.id]
        invoice.reload
        expect(invoice.paid_features.pluck(:id)).to eq([paid_feature3.id])
        put :update, organization_id: organization.to_param, id: invoice.to_param, invoice: params.merge(end_at: "2019-07-05T23:00:00")
        invoice.reload
        expect(invoice.paid_feature_ids).to match_array([paid_feature1.id, paid_feature2.id])
        expect(invoice.amount_due).to eq 1220
        # TimeParser isn't storing records perfectly - for now, just ignoring since fix can be separate
        expect(invoice.subscription_start_at.to_i).to be_within(1.day).of 1536202800
        expect(invoice.subscription_end_at.to_i).to be_within(1.day).of 1562385600
        expect(invoice.notes).to eq params[:notes]
      end
      context "create_following_invoice" do
        let!(:invoice) { FactoryBot.create(:invoice, organization: organization, subscription_start_at: Time.now - 2.years, force_active: true) }
        it "creates following invoice" do
          expect do
            put :update, organization_id: organization.to_param, id: invoice.to_param, create_following_invoice: true
          end.to change(Invoice, :count).by 1
          invoice.reload
          following_invoice = invoice.following_invoice
          expect(following_invoice.previous_invoice).to eq invoice
          expect(following_invoice.notes).to be_nil
        end
      end
    end
  end
end
