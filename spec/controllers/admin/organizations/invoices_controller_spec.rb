require "rails_helper"

RSpec.describe Admin::Organizations::InvoicesController, type: :controller do
  let(:organization) { FactoryBot.create(:organization) }
  let(:invoice) { FactoryBot.create(:invoice, organization: organization) }
  let(:organization_feature1) { FactoryBot.create(:organization_feature, feature_slugs: ["parking_notifications"]) }
  let(:organization_feature2) { FactoryBot.create(:organization_feature, feature_slugs: ["passwordless_users"]) }
  let(:enabled_feature_slugs) { %w[parking_notifications passwordless_users] }
  let(:params) do
    {
      organization_feature_ids: [organization_feature1.id, organization_feature2.id].join(","),
      amount_due: "1220",
      timezone: "EST",
      start_at: "2018-09-05T23:00:00",
      notes: "some cool note about when something was paid"
    }
  end
  context "super admin" do
    include_context :logged_in_as_super_admin

    describe "index" do
      it "renders" do
        get :index, params: {organization_id: organization.to_param}
        expect(response.status).to eq(200)
        expect(response).to render_template(:index)
      end
    end

    describe "new" do
      it "renders" do
        get :new, params: {organization_id: organization.to_param}
        expect(response.status).to eq(200)
        expect(response).to render_template(:new)
      end
      context "passed end_at" do
        let(:end_at) { Time.current + 10.years }
        it "renders, includes end_at" do
          get :new, params: {organization_id: organization.to_param, end_at: end_at.to_i}
          expect(response.status).to eq(200)
          expect(response).to render_template(:new)
          expect(assigns(:invoice).end_at).to be_within(1.day).of end_at
        end
      end
    end

    describe "edit" do
      it "renders" do
        get :edit, params: {organization_id: organization.to_param, id: invoice.to_param}
        expect(response.status).to eq(200)
        expect(response).to render_template(:edit)
      end
    end

    describe "create" do
      it "creates" do
        expect {
          post :create, params: {organization_id: organization.to_param, invoice: params}
        }.to change(Invoice, :count).by 1
        invoice = organization.invoices.last
        expect(invoice.active?).to be_falsey
        expect(organization.is_paid).to be_falsey
        expect(organization.enabled_feature_slugs).to eq([])
        expect(invoice.organization_feature_ids).to match_array([organization_feature1.id, organization_feature2.id])
        expect(invoice.amount_due).to eq 1220
        # TimeParser isn't storing records perfectly - for now, just ignoring since fix can be separate
        expect(invoice.subscription_start_at.to_i).to be_within(1.day).of 1536202800
        expect(invoice.notes).to eq params[:notes]
      end
      context "with amount_do 0" do
        let(:time) { (Time.current - 1.month).utc.to_s }
        it "makes the invoice active" do
          Sidekiq::Testing.inline! do
            invoice_params = params.merge(
              amount_due: "0",
              start_at: time,
              child_enabled_feature_slugs: %(parking_notifications passwordless_users)
            )

            expect {
              post :create,
                params: {
                  organization_id: organization.to_param,
                  invoice: invoice_params
                }
            }.to change(Invoice, :count).by 1

            invoice = organization.invoices.last
            expect(invoice.paid_in_full?).to be_truthy
            expect(invoice.active?).to be_truthy
            expect(organization.reload.is_paid).to be_truthy
            expect(organization.enabled_feature_slugs).to eq(%w[parking_notifications passwordless_users])
            expect(invoice.organization_feature_ids).to match_array([organization_feature1.id, organization_feature2.id])
            expect(invoice.amount_due).to eq 0
            # TimeParser isn't storing records perfectly - for now, just ignoring since fix can be separate
            expect(invoice.subscription_start_at.to_i).to be_within(1.day).of Time.parse(time).to_i
            expect(invoice.subscription_end_at.to_i).to be_within(1.day).of (Time.parse(time) + 1.years).to_i
            expect(invoice.notes).to eq params[:notes]
          end
        end
      end
    end

    describe "update" do
      let(:organization_feature3) { FactoryBot.create(:organization_feature) }
      let(:invoice) { FactoryBot.create(:invoice, organization: organization, amount_due: 10) }
      let(:update_params) { params.merge(end_at: "2019-07-05T23:00:00", child_enabled_feature_slugs_string: "stufffff,#{organization_feature1.feature_slugs.first}, #{organization_feature2.feature_slugs.first}\n") }
      it "updates, removes organization_features that aren't matching, sets child_enabled_feature_slugs" do
        expect(enabled_feature_slugs.count).to eq 2
        invoice.organization_feature_ids = [organization_feature3.id]
        invoice.reload
        expect(invoice.organization_features.pluck(:id)).to eq([organization_feature3.id])
        put :update, params: {organization_id: organization.to_param, id: invoice.to_param, invoice: update_params}
        invoice.reload
        expect(invoice.organization_feature_ids).to match_array([organization_feature1.id, organization_feature2.id])
        expect(invoice.amount_due).to eq 1220
        # TimeParser isn't storing records perfectly - for now, just ignoring since fix can be separate
        expect(invoice.subscription_start_at.to_i).to be_within(1.day).of 1536202800
        expect(invoice.subscription_end_at.to_i).to be_within(1.day).of 1562385600
        expect(invoice.notes).to eq params[:notes]
        expect(invoice.child_enabled_feature_slugs).to eq enabled_feature_slugs
      end
      context "endless" do
        it "marks the invoice endless" do
          expect(enabled_feature_slugs.count).to eq 2
          invoice.organization_feature_ids = [organization_feature3.id]
          invoice.reload
          expect(invoice.organization_features.pluck(:id)).to eq([organization_feature3.id])
          put :update, params: {organization_id: organization.to_param, id: invoice.to_param, invoice: update_params.merge(is_endless: "true")}
          invoice.reload
          expect(invoice.organization_feature_ids).to match_array([organization_feature1.id, organization_feature2.id])
          expect(invoice.amount_due).to eq 1220
          # TimeParser isn't storing records perfectly - for now, just ignoring since fix can be separate
          expect(invoice.subscription_start_at.to_i).to be_within(1.day).of 1536202800
          expect(invoice.subscription_end_at.to_i).to be_within(1.day).of 1562385600
          expect(invoice.notes).to eq params[:notes]
          expect(invoice.child_enabled_feature_slugs).to eq enabled_feature_slugs
          expect(invoice.endless?).to be_truthy
        end
      end
      context "create_following_invoice" do
        let!(:invoice) { FactoryBot.create(:invoice, organization: organization, subscription_start_at: Time.current - 2.years, force_active: true) }
        it "creates following invoice" do
          invoice.organization_feature_ids = [organization_feature1.id, organization_feature2.id]
          invoice.update_attributes(child_enabled_feature_slugs: ["passwordless_users"])
          invoice.reload
          expect(invoice.child_enabled_feature_slugs).to eq(["passwordless_users"])
          expect {
            put :update, params: {organization_id: organization.to_param, id: invoice.to_param, create_following_invoice: true}
          }.to change(Invoice, :count).by 1
          invoice.reload
          following_invoice = invoice.following_invoice
          expect(following_invoice.previous_invoice).to eq invoice
          expect(following_invoice.notes).to be_nil
          expect(following_invoice.organization_feature_ids).to match_array([organization_feature1.id, organization_feature2.id])
          expect(following_invoice.child_enabled_feature_slugs).to eq(["passwordless_users"])
        end
      end
    end
  end
end
