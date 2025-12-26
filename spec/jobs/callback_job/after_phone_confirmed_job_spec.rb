require "rails_helper"

RSpec.describe CallbackJob::AfterPhoneConfirmedJob, type: :job do
  let(:subject) { described_class }
  let(:instance) { subject.new }

  it "is the correct queue" do
    expect(subject.sidekiq_options["queue"]).to eq "high_priority"
  end

  context "confirmed" do
    let(:phone) { "2221113333" }
    let(:user) { FactoryBot.create(:user_confirmed, phone: nil) }
    let!(:user_phone) { FactoryBot.create(:user_phone, user: user, phone: phone) }
    let(:bike) { FactoryBot.create(:bike, :phone_registration, owner_email: phone) }
    let!(:ownership) { FactoryBot.create(:ownership, is_phone: true, owner_email: phone, bike: bike) }

    context "it adds the bike to the user" do
      it "adds the bike" do
        ::CallbackJob::AfterUserChangeJob.new.perform(user.id, user)
        expect(user.alert_slugs).to eq(["phone_waiting_confirmation"])

        bike.reload
        expect(bike.phone_registration?).to be_truthy
        expect(bike.current_ownership.phone_registration?).to be_truthy
        expect(bike.current_ownership.claimed?).to be_falsey

        user_phone.confirm!
        user_phone.reload
        expect(user_phone.confirmed?).to be_truthy
        expect {
          instance.perform(user_phone.id)
        }.to change(Ownership, :count).by 1
        bike.reload
        expect(bike.phone_registration?).to be_falsey
        expect(bike.owner_email).to eq(user.email)
        expect(bike.current_ownership.phone_registration?).to be_falsey
        expect(bike.current_ownership.claimed?).to be_truthy
        expect(ownership.current?).to be_truthy
        expect(bike.current_ownership.calculated_send_email).to be_falsey
        expect(bike.current_ownership.owner_email).to eq user.email
        expect(bike.current_ownership.user_id).to eq user.id
        expect(bike.current_ownership.creator_id).to eq user.id

        ownership.reload
        expect(ownership.phone_registration?).to be_truthy
        expect(ownership.claimed?).to be_truthy
        expect(ownership.current?).to be_falsey
        expect(ownership.owner_email).to eq phone
        expect(ownership.user_id).to eq user.id
        expect(ownership.creator_id).to_not eq user.id
      end
    end
  end
end
