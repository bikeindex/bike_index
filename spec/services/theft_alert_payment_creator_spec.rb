require "rails_helper"

RSpec.describe TheftAlertPaymentCreator, type: :service, vcr: true do
  describe ".create" do
    let(:user) { FactoryBot.create(:user_confirmed) }

    before do
      expect(Payment.count).to eq(0)
    end

    context "given a successful Stripe charge and Theft Alert creation" do
      it "persists and returns the Payment" do
        payment = described_class.create!(
          user: user,
          stripe_email: user.email,
          stripe_token: stripe_token.id,
          stripe_amount: 900,
        )

        expect(Payment.count).to eq(1)
        expect(payment).to be_persisted
      end
    end

    context "given an invalid Stripe request" do
      it "raises RecordInvalid" do
        service = -> do
          described_class.create!(
            user: user,
            stripe_email: user.email,
            stripe_token: stripe_token.id,
            stripe_amount: -99,
          )
        end

        expect { service.call }.to raise_error(Stripe::InvalidRequestError)
        expect(Payment.count).to eq(0)
      end
    end

    context "given a Stripe credit card decline error" do
      it "raises RecordInvalid" do
        declined_card_token = stripe_token(:declined).id

        service = -> do
          described_class.create!(
            user: user,
            stripe_email: user.email,
            stripe_token: declined_card_token,
            stripe_amount: 100,
          )
        end

        expect { service.call }.to raise_error(Stripe::CardError)
        expect(Payment.count).to eq(0)
      end
    end
  end
end
