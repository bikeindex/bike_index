require "rails_helper"

RSpec.describe MembershipSerializer do
  let(:organization) { FactoryBot.create(:organization) }
  let(:user) { FactoryBot.create(:user) }
  let(:organization_role) { FactoryBot.create(:organization_role_claimed, organization_id: organization.id, user_id: user.id, role: "member") }
  subject { MembershipSerializer.new(organization_role) }

  let(:target) do
    {
      base_url: "/organizations/#{organization.slug}",
      is_admin: false,
      locations: [{id: nil,  name: organization.name}],
      organization_id: organization.id,
      organization_name: organization.name,
      short_name: organization.short_name,
      slug: organization.slug
    }
  end
  it "is expected" do
    expect(subject.as_json(root: false)).to eq target
  end
end
