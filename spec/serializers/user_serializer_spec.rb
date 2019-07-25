require "rails_helper"

RSpec.describe UserSerializer do
  let(:user) { FactoryBot.create(:user) }
  let(:organization) { FactoryBot.create(:organization) }
  let(:membership) { FactoryBot.create(:membership_claimed, user: user, organization: organization) }
  subject { UserSerializer.new(user) }

  it { expect(subject.user_present).to be_truthy }
  it { expect(subject.is_superuser).to be_falsey }
  xit { expect(subject.memberships.first).to eq(membership) }
end
