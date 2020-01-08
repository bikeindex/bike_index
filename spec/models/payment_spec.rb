require "rails_helper"

RSpec.describe Payment, type: :model do
  it_behaves_like "amountable"
  describe "create" do
    context "stripe" do
      let(:user) { FactoryBot.create(:user) }
      let(:payment) { FactoryBot.create(:payment, user: nil, email: user.email) }
      it "enqueues an email job, associates the user" do
        expect do
          payment
        end.to change(EmailInvoiceWorker.jobs, :size).by(1)
        payment.reload
        expect(payment.id).to be_present
        expect(payment.user_id).to eq user.id
      end
    end
    context "check with organization_id but no user or email" do
      let(:organization) { FactoryBot.create(:organization) }
      let(:payment) { FactoryBot.create(:payment_check, user: nil, email: nil, organization: organization) }
      it "does not enqueue an email" do
        expect do
          payment # it is created here
        end.to_not change(EmailInvoiceWorker.jobs, :size)
        expect(payment.valid?).to be_truthy
        payment.reload
        expect(payment.id).to be_present
      end
    end
  end

  describe "set_calculated_attributes" do
    let(:payment) { Payment.new }
    it "sets donation" do
      payment.set_calculated_attributes
      expect(payment.kind).to eq "donation"
    end
    context "theft_alert" do
      let(:payment) { Payment.new(kind: "theft_alert") }
      it "does not change from theft_alert" do
        payment.set_calculated_attributes
        expect(payment.kind).to eq "theft_alert"
      end
    end
    context "payment" do
      let(:payment) { Payment.new(kind: "payment") }
      it "stays payment" do
        payment.set_calculated_attributes
        expect(payment.kind).to eq "payment"
      end
      context "with invoice" do
        let(:invoice) { Invoice.new }
        it "becomes invoice" do
          payment.invoice = invoice
          payment.set_calculated_attributes
          expect(payment.kind).to eq "payment"
        end
      end
    end
  end
end
