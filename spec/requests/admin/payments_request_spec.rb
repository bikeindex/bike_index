require "rails_helper"

base_url = "/admin/payments"
RSpec.describe Admin::PaymentsController, type: :request do
  include_context :request_spec_logged_in_as_superuser
  let(:subject) { FactoryBot.create(:payment, user: current_user) }
  let(:organization) { FactoryBot.create(:organization) }
  let(:invoice) { FactoryBot.create(:invoice, organization: organization) }
  let(:user2) { FactoryBot.create(:user) }
  let(:create_time) { Time.current - 2.weeks }
  let(:params) do
    {
      organization_id: organization.id,
      invoice_id: invoice.id,
      email: user2.email,
      amount: 222.22,
      payment_method: "stripe",
      created_at: create_time.strftime("%FT%T%:z")
    }
  end

  describe "index" do
    it "renders" do
      get base_url
      expect(response.status).to eq(200)
      expect(response).to render_template(:index)
    end
  end

  describe "edit" do
    it "renders" do
      get "#{base_url}/#{subject.to_param}/edit"
      expect(response.status).to eq(200)
      expect(response).to render_template(:edit)
    end
  end

  describe "new" do
    it "renders" do
      get "#{base_url}/new"
      expect(response.status).to eq(200)
      expect(response).to render_template(:new)
    end
  end

  describe "update" do
    context "stripe payment" do
      let(:og_time) { Time.current - 3.hours }
      let(:invoice) { FactoryBot.create(:invoice, organization: organization, updated_at: og_time) }
      it "updates available attributes" do
        expect(subject.invoice).to be_nil

        put "#{base_url}/#{subject.to_param}", params: {payment: params.merge(referral_source: "fasdf")}

        subject.reload
        expect(subject.organization).to eq organization
        expect(subject.invoice).to eq invoice
        expect(subject.referral_source).to eq "fasdf"
        # Not changed attrs:
        expect(subject.payment_method).to eq "stripe"
        expect(subject.created_at).to be_within(1.minute).of Time.current
        expect(subject.user).to eq current_user
        expect(subject.amount_cents).to_not eq 22_222
        expect(subject.kind).to eq "invoice_payment"
        expect(invoice.reload.updated_at).to be_within(1.second).of Time.current
      end
    end
    context "check payment" do
      let(:subject) { FactoryBot.create(:payment_check, organization: nil, amount_cents: 55_555, user: current_user) }
      it "updates available attributes" do
        patch "#{base_url}/#{subject.to_param}", params: {payment: params}
        subject.reload
        expect(subject.organization).to eq organization
        expect(subject.invoice).to eq invoice
        # Not changed attrs:
        expect(subject.payment_method).to eq "check"
        expect(subject.created_at).to be_within(1.minute).of Time.current
        expect(subject.user).to eq current_user
        expect(subject.email).to eq current_user.email
        expect(subject.amount_cents).to eq 55555
      end
      context "no invoice" do
        it "updates available attributes" do
          put "#{base_url}/#{subject.to_param}", params: {payment: params.merge(invoice_id: "")}
          subject.reload
          expect(subject.organization).to eq organization
          expect(subject.invoice).to be_nil
          # Not changed attrs:
          expect(subject.payment_method).to eq "check"
          expect(subject.created_at).to be_within(1.minute).of Time.current
          expect(subject.user).to eq current_user
          expect(subject.email).to eq current_user.email
          expect(subject.amount_cents).to eq 55555
        end
      end
      context "invoice for different organization" do
        let(:invoice) { FactoryBot.create(:invoice) }
        let!(:subject) { FactoryBot.create(:payment_check, organization: organization, amount_cents: 55_555, user: current_user, invoice: nil) }
        it "Does not update" do
          expect(invoice.organization).to_not eq organization
          expect(subject.organization).to eq organization
          put "#{base_url}/#{subject.to_param}", params: {payment: params}
          expect(flash[:error]).to match(/#{organization.short_name}/)
          subject.reload
          expect(subject.invoice).to be_nil
        end
      end
    end
  end

  describe "create" do
    context "stripe payment" do
      it "does not create" do
        expect {
          post base_url, params: {payment: params.merge(payment_method: "stripe")}
          expect(flash[:error]).to match(/stripe/i)
        }.to_not change(Payment, :count)
      end
    end
    context "check payment" do
      it "creates" do
        payment_attrs = params.merge(payment_method: "check")

        expect {
          post base_url, params: {payment: payment_attrs}
        }.to change(Payment, :count).by 1

        payment = Payment.last
        expect(payment.organization).to eq organization
        expect(payment.invoice).to eq invoice
        expect(payment.user).to eq user2
        expect(payment.email).to eq user2.email
        expect(payment.amount_cents).to eq 22_222
        expect(payment.payment_method).to eq "check"
        expect(payment.created_at).to be_within(1.minute).of create_time
        expect(payment.paid?).to be_truthy
      end
      context "no organization" do
        it "creates" do
          payment_attrs =
            params.merge(payment_method: "check",
              organization_id: "",
              invoice_id: "Invoice ##{invoice.id}")
          expect {
            post base_url, params: {payment: payment_attrs}
          }.to change(Payment, :count).by 1

          payment = Payment.last
          expect(payment.organization).to eq organization
          expect(payment.invoice).to eq invoice
          expect(payment.user).to eq user2
          expect(payment.email).to eq user2.email
          expect(payment.amount_cents).to eq 22_222
          expect(payment.payment_method).to eq "check"
          expect(payment.created_at).to be_within(1.minute).of create_time
          expect(payment.paid?).to be_truthy
          expect(payment.paid_at).to be_within(1.minute).of create_time
        end
      end
    end
  end
end
