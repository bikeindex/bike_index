require "spec_helper"

describe MembershipSerializer do
  let(:organization) { FactoryGirl.create(:organization) }
  let(:user) { FactoryGirl.create(:user)}
  let(:membership) { FactoryGirl.create(:membership, organization_id: organization.id, user_id: user.id, role: "member")}
  subject { MembershipSerializer.new(membership) }
  
  it { subject.organization_name.should == organization.name }
  it { subject.short_name.should == organization.short_name }
  it { subject.organization_id.should == organization.id }
  it { subject.slug.should == organization.slug }
  it { subject.is_admin.should be_false }
  it { subject.locations.should == [{ name: organization.name, id: nil}] }

end
