require "rails_helper"

RSpec.describe Admin::Organizations::InvoicesController, type: :controller do
  let(:organization) { FactoryBot.create(:organization) }
  let(:invoice) { FactoryBot.create(:invoice, organization: organization) }
  let(:paid_feature1) { FactoryBot.create(:paid_feature, feature_slugs: ["abandoned_bike_messages"]) }
  let(:paid_feature2) { FactoryBot.create(:paid_feature, feature_slugs: ["passwordless_users"]) }
  let(:paid_feature_slugs) { %w[abandoned_bike_messages passwordless_users] }
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
        get :index, params: { organization_id: organization.to_param }
        expect(response.status).to eq(200)
        expect(response).to render_template(:index)
      end
    end

    describe "new" do
      it "renders" do
        get :new, params: { organization_id: organization.to_param }
        expect(response.status).to eq(200)
        expect(response).to render_template(:new)
      end
      context "passed end_at" do
        let(:end_at) { Time.current + 10.years }
        it "renders, includes end_at" do
          get :new, params: { organization_id: organization.to_param, end_at: end_at.to_i }
          expect(response.status).to eq(200)
          expect(response).to render_template(:new)
          expect(assigns(:invoice).end_at).to be_within(1.day).of end_at
        end
      end
    end

    describe "edit" do
      it "renders" do
        get :edit, params: { organization_id: organization.to_param, id: invoice.to_param }
        expect(response.status).to eq(200)
        expect(response).to render_template(:edit)
      end
    end

    describe "create" do
      it "creates" do
        expect do
          post :create, params: { organization_id: organization.to_param, invoice: params }
        end.to change(Invoice, :count).by 1
        # TODO: Rails 5 update
        organization.update_attributes(updated_at: Time.current)
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
            post :create, params: { organization_id: organization.to_param, invoice: params.merge(amount_due: "0", end_at: "2020-09-05T23:00:00", child_paid_feature_slugs: %[abandoned_bike_messages passwordless_users]) }
          end.to change(Invoice, :count).by 1
          # TODO: Rails 5 update
          organization.update_attributes(updated_at: Time.current)
          invoice = organization.invoices.last
          expect(invoice.active?).to be_truthy
          expect(organization.is_paid).to be_truthy
          expect(organization.paid_feature_slugs).to eq(%w[abandoned_bike_messages passwordless_users])
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
      let(:update_params) { params.merge(end_at: "2019-07-05T23:00:00", child_paid_feature_slugs_string: "stufffff,#{paid_feature1.feature_slugs.first}, #{paid_feature2.feature_slugs.first}\n") }
      it "updates, removes paid_features that aren't matching, sets child_paid_feature_slugs" do
        expect(paid_feature_slugs.count).to eq 2
        invoice.paid_feature_ids = [paid_feature3.id]
        invoice.reload
        expect(invoice.paid_features.pluck(:id)).to eq([paid_feature3.id])
        put :update, params: { organization_id: organization.to_param, id: invoice.to_param, invoice: update_params }
        invoice.reload
        expect(invoice.paid_feature_ids).to match_array([paid_feature1.id, paid_feature2.id])
        expect(invoice.amount_due).to eq 1220
        # TimeParser isn't storing records perfectly - for now, just ignoring since fix can be separate
        expect(invoice.subscription_start_at.to_i).to be_within(1.day).of 1536202800
        expect(invoice.subscription_end_at.to_i).to be_within(1.day).of 1562385600
        expect(invoice.notes).to eq params[:notes]
        expect(invoice.child_paid_feature_slugs).to eq paid_feature_slugs
      end
      context "create_following_invoice" do
        let!(:invoice) { FactoryBot.create(:invoice, organization: organization, subscription_start_at: Time.current - 2.years, force_active: true) }
        it "creates following invoice" do
          invoice.paid_feature_ids = [paid_feature1.id, paid_feature2.id]
          invoice.update_attributes(child_paid_feature_slugs: ["passwordless_users"])
          invoice.reload
          expect(invoice.child_paid_feature_slugs).to eq(["passwordless_users"])
          expect do
            put :update, params: { organization_id: organization.to_param, id: invoice.to_param, create_following_invoice: true }
          end.to change(Invoice, :count).by 1
          invoice.reload
          following_invoice = invoice.following_invoice
          expect(following_invoice.previous_invoice).to eq invoice
          expect(following_invoice.notes).to be_nil
          expect(following_invoice.paid_feature_ids).to match_array([paid_feature1.id, paid_feature2.id])
          expect(following_invoice.child_paid_feature_slugs).to eq(["passwordless_users"])
        end
      end
    end
  end
end
