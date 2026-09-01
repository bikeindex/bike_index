require "rails_helper"

RSpec.describe StripeAccount, type: :model do
  describe "factory" do
    let(:stripe_account) { FactoryBot.create(:stripe_account) }

    it "is not payable until stripe says so" do
      expect(stripe_account).to be_valid
      expect(stripe_account).to_not be_payable
      expect(stripe_account.onboarding_started?).to be_truthy
    end
  end

  describe "for!" do
    let(:user) { FactoryBot.create(:user_confirmed) }

    it "doesn't create a second account for the same holder" do
      stripe_account = described_class.for!(user)

      expect(described_class.for!(user).id).to eq stripe_account.id
      expect(user.reload.stripe_account.id).to eq stripe_account.id
      expect(stripe_account.onboarding_started?).to be_falsey
    end

    context "an organization" do
      let(:organization) { FactoryBot.create(:organization) }

      it "holds an account too - shops get paid the same way" do
        expect(described_class.for!(organization).account_holder).to eq organization
        expect(organization.reload.stripe_account).to be_present
      end
    end
  end

  describe "update_from_stripe!" do
    let(:stripe_account) { FactoryBot.create(:stripe_account, stripe_id: "acct_1") }
    let(:stripe_obj) do
      {"id" => "acct_1", "charges_enabled" => true, "payouts_enabled" => true,
       "details_submitted" => true}
    end

    it "becomes payable and records when" do
      stripe_account.update_from_stripe!(stripe_obj)

      expect(stripe_account.reload).to be_payable
      expect(stripe_account.onboarded_at).to be_present
    end

    # somebody can finish the onboarding form and still not be payable
    context "details submitted but payouts still disabled" do
      let(:stripe_obj) do
        {"id" => "acct_1", "charges_enabled" => false, "payouts_enabled" => false,
         "details_submitted" => true}
      end

      it "is not payable" do
        stripe_account.update_from_stripe!(stripe_obj)

        expect(stripe_account.reload).to_not be_payable
        expect(stripe_account.details_submitted).to be_truthy
        expect(stripe_account.onboarded_at).to be_blank
      end
    end

    context "stripe later disables payouts" do
      let(:stripe_account) { FactoryBot.create(:stripe_account, :payable, stripe_id: "acct_1") }
      let(:stripe_obj) do
        {"id" => "acct_1", "charges_enabled" => true, "payouts_enabled" => false,
         "details_submitted" => true}
      end

      it "stops being payable, but keeps when it first onboarded" do
        onboarded_at = stripe_account.onboarded_at
        stripe_account.update_from_stripe!(stripe_obj)

        expect(stripe_account.reload).to_not be_payable
        expect(stripe_account.onboarded_at).to be_within(1).of(onboarded_at)
      end
    end
  end

  describe "payable scope" do
    let!(:payable) { FactoryBot.create(:stripe_account, :payable) }
    let!(:pending) { FactoryBot.create(:stripe_account) }

    it "only includes the payable one" do
      expect(described_class.payable.pluck(:id)).to eq([payable.id])
    end
  end
end
