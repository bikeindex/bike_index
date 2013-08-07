require "spec_helper"

describe UserSerializer do
  let(:user) { FactoryGirl.create(:user) }
  let(:organization) { FactoryGirl.create(:organization) }
  let(:membership) { FactoryGirl.create(:membership, user: user, organization: organization) }
  subject { UserSerializer.new(user) }

  it { subject.user_present.should be_true }
  it { subject.is_superuser.should be_false }
  xit { subject.memberships.first.should eq(membership) }

end
