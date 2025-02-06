require "rails_helper"

RSpec.describe UserSerializer do
  let(:user) { FactoryBot.create(:user) }
  let!(:organization_role) { FactoryBot.create(:organization_role_claimed, user: user) }
  let(:organization) { organization_role.organization }
  subject { UserSerializer.new(user.reload) }

  let(:target_organization_role) do
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
  let(:target) do
    {
      user_present: true,
      is_content_admin: false,
      is_superuser: nil,
      organization_roles: [target_organization_role]
    }
  end
  it "renders" do
    expect(subject.as_json(root: false)).to eq target
  end
end
