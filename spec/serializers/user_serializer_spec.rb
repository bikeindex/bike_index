require "spec_helper"

describe UserSerializer do
  let(:user) { FactoryGirl.create(:user) }
  let(:organization) { FactoryGirl.create(:organization) }
  let(:membership) { FactoryGirl.create(:membership, user: user, organization: organization) }
  subject { UserSerializer.new(user) }

  it { expect(subject.user_present).to be_truthy }
  it { expect(subject.is_superuser).to be_falsey }
  xit { expect(subject.memberships.first).to eq(membership) }

end
