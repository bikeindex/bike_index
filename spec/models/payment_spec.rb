require "rails_helper"

RSpec.describe Payment, type: :model do
  it_behaves_like "amountable"
  it_behaves_like "currencyable"

  describe "normalize_referral_source" do
    it "is nil" do
      expect(Payment.normalize_referral_source("\n")).to be_nil
    end
    it "removes bikeindex" do
      expect(Payment.normalize_referral_source("\nhttps://bikeindex.org/BIKES")).to eq "bikes"
      expect(Payment.normalize_referral_source("\nbikeindex.org/BIKES")).to eq "bikes"
      expect(Payment.normalize_referral_source(" bikeindex.org BIKES ")).to eq "bikes"
    end
    it "replaces slashes and spaces" do
      expect(Payment.normalize_referral_source("BIKES 12")).to eq "bikes-12"
      expect(Payment.normalize_referral_source("BIKES/12")).to eq "bikes-12"
      expect(Payment.normalize_referral_source("BIKES_12")).to eq "bikes-12"
    end
  end

  describe "admin_search" do
    let!(:payment1) { FactoryBot.create(:payment, referral_source: "something%20special") }
    let!(:payment2) { FactoryBot.create(:payment, referral_source: "something/else/special", email: "sTUFF@things.com ", user: nil) }
    it "searches by referral_source" do
      expect(payment1.reload.referral_source).to eq "something-special"
      expect(payment2.reload.referral_source).to eq "something-else-special"
      expect(payment2.email).to eq "stuff@things.com"
      expect(Payment.admin_search("special").pluck(:id)).to match_array([payment1.id, payment2.id])
      expect(Payment.admin_search("something_special").pluck(:id)).to match_array([payment1.id])
      expect(Payment.admin_search("\nsomething ").pluck(:id)).to match_array([payment1.id, payment2.id])
    end
  end

  describe "create" do
    context "stripe" do
      let(:user) { FactoryBot.create(:user) }
      let(:payment) { FactoryBot.create(:payment, user: nil, email: user.email, referral_source: "\n") }
      it "enqueues an email job, associates the user" do
        expect {
          payment
        }.to change(EmailReceiptJob.jobs, :size).by(1)
        payment.reload
        expect(payment.id).to be_present
        expect(payment.user_id).to eq user.id
        expect(payment.referral_source).to be_nil
      end
      context "theft_alert" do
        let(:payment) { FactoryBot.create(:payment, user: nil, kind: "theft_alert", email: user.email) }
        it "does not send an extra email" do
          expect {
            payment
          }.to change(EmailReceiptJob.jobs, :size).by 0
          payment.reload
          expect(payment.id).to be_present
          expect(payment.user_id).to eq user.id
        end
      end
    end
    context "check with organization_id but no user or email" do
      let(:organization) { FactoryBot.create(:organization) }
      let(:payment) { FactoryBot.create(:payment_check, user: nil, email: " ", organization: organization) }
      it "does not enqueue an email" do
        expect {
          payment # it is created here
        }.to_not change(EmailReceiptJob.jobs, :size)
        expect(payment.valid?).to be_truthy
        payment.reload
        expect(payment.id).to be_present
        expect(payment.email).to be_nil
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
      expect(UpdateMailchimpDatumJob::UPDATE_MAILCHIMP).to be_falsey
      Sidekiq::Job.clear_all
      Sidekiq::Testing.inline! do
        payment.reload
      end
      user.reload
      expect(user.mailchimp_datum).to be_present
      expect(user.mailchimp_datum.interests).to eq(["donors"])
    end
  end
end
