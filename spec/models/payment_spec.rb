require "rails_helper"

RSpec.describe Payment, type: :model do
  it_behaves_like "amountable"
  describe "create" do
    context "stripe" do
      let(:user) { FactoryBot.create(:user) }
      let(:payment) { FactoryBot.create(:payment, user: nil, email: user.email) }
      it "enqueues an email job, associates the user" do
        expect {
          payment
        }.to change(EmailReceiptWorker.jobs, :size).by(1)
        payment.reload
        expect(payment.id).to be_present
        expect(payment.user_id).to eq user.id
      end
      context "theft_alert" do
        let(:payment) { FactoryBot.create(:payment, user: nil, kind: "theft_alert", email: user.email) }
        it "does not send an extra email" do
          expect {
            payment
          }.to change(EmailReceiptWorker.jobs, :size).by 0
          payment.reload
          expect(payment.id).to be_present
          expect(payment.user_id).to eq user.id
        end
      end
    end
    context "check with organization_id but no user or email" do
      let(:organization) { FactoryBot.create(:organization) }
      let(:payment) { FactoryBot.create(:payment_check, user: nil, email: nil, organization: organization) }
      it "does not enqueue an email" do
        expect {
          payment # it is created here
        }.to_not change(EmailReceiptWorker.jobs, :size)
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

  describe "stripe_success_url, stripe_cancel_url" do
    let(:target_success) { "http://test.host/payments/success?session_id={CHECKOUT_SESSION_ID}" }
    let(:target_cancel) { "http://test.host/payments/new" }
    let(:payment) { Payment.new }
    it "is expected" do
      expect(payment.stripe_success_url).to eq target_success
      expect(payment.stripe_cancel_url).to eq target_cancel
    end
    context "theft_alert" do
      let(:theft_alert) { FactoryBot.create(:theft_alert) }
      let(:payment) { Payment.new(kind: "theft_alert", theft_alert: theft_alert) }
      let(:target_success) { "http://test.host/bikes/#{theft_alert.bike_id}/theft_alert?session_id={CHECKOUT_SESSION_ID}" }
      let(:target_cancel) { "http://test.host/bikes/#{theft_alert.bike_id}/theft_alert/new" }
      it "returns expected" do
        expect(payment.stripe_success_url).to eq target_success
        expect(payment.stripe_cancel_url).to eq target_cancel
      end
    end
  end

  describe "after_commit" do
    let(:user) { FactoryBot.create(:user) }
    let(:payment) { FactoryBot.create(:payment, kind: "donation", user: user) }
    it "creates a mailchimp_datum" do
      user.reload
      expect(user.mailchimp_datum).to be_blank
      UpdateMailchimpDatumWorker.new # So that it's present post stubbing
      expect(UpdateMailchimpDatumWorker::UPDATE_MAILCHIMP).to be_falsey
      Sidekiq::Worker.clear_all
      Sidekiq::Testing.inline! do
        payment.reload
      end
      user.reload
      expect(user.mailchimp_datum).to be_present
      expect(user.mailchimp_datum.interests).to eq(["donors"])
    end
  end
end
