require "rails_helper"

RSpec.describe EmailConfirmationWorker, type: :job do
  it "sends a welcome email" do
    user = FactoryBot.create(:user)
    ActionMailer::Base.deliveries = []
    EmailConfirmationWorker.new.perform(user.id)
    expect(ActionMailer::Base.deliveries.empty?).to be_falsey
  end
  context "user with email already exists" do
    let(:email) { "test@test.com" }
    let!(:user1) { FactoryBot.create(:user, email: email) }
    let(:user2) do
      u = FactoryBot.create(:user)
      u.update_column :email, email
      u
    end
    it "deletes user" do
      expect(user1.email).to eq user2.email
      expect(user1.id).to be < user2.id
      ActionMailer::Base.deliveries = []
      expect do
        EmailConfirmationWorker.new.perform(user2.id)
      end.to change(User, :count).by(-1)
      expect(ActionMailer::Base.deliveries.empty?).to be_truthy
    end
    context "calling other user" do
      it "does not delete the other user" do
        expect(user1.id).to be < user2.id
        ActionMailer::Base.deliveries = []
        expect do
          EmailConfirmationWorker.new.perform(user1.id)
        end.to change(User, :count).by(0)
        expect(ActionMailer::Base.deliveries.empty?).to be_falsey
      end
    end
  end
end
