require "spec_helper"

describe MembershipSerializer do
  let(:organization) { FactoryGirl.create(:organization) }
  let(:user) { FactoryGirl.create(:user)}
  let(:membership) { FactoryGirl.create(:membership, organization_id: organization.id, user_id: user.id, role: "member")}
  subject { MembershipSerializer.new(membership) }
  
  it { expect(subject.organization_name).to eq(organization.name) }
  it { expect(subject.short_name).to eq(organization.short_name) }
  it { expect(subject.organization_id).to eq(organization.id) }
  it { expect(subject.slug).to eq(organization.slug) }
  it { expect(subject.is_admin).to be_falsey }
  it { expect(subject.locations).to eq([{ name: organization.name, id: nil}]) }

end
