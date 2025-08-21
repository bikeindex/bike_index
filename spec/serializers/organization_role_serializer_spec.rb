# == Schema Information
#
# Table name: organization_roles
#
#  id                       :integer          not null, primary key
#  claimed_at               :datetime
#  created_by_magic_link    :boolean          default(FALSE)
#  deleted_at               :datetime
#  email_invitation_sent_at :datetime
#  hot_sheet_notification   :integer          default("notification_never")
#  invited_email            :string(255)
#  receive_hot_sheet        :boolean          default(FALSE)
#  role                     :integer
#  created_at               :datetime         not null
#  updated_at               :datetime         not null
#  organization_id          :integer          not null
#  sender_id                :integer
#  user_id                  :integer
#
# Indexes
#
#  index_organization_roles_on_organization_id  (organization_id)
#  index_organization_roles_on_sender_id        (sender_id)
#  index_organization_roles_on_user_id          (user_id)
#
require "rails_helper"

RSpec.describe OrganizationRoleSerializer do
  let(:organization) { FactoryBot.create(:organization) }
  let(:user) { FactoryBot.create(:user) }
  let(:organization_role) { FactoryBot.create(:organization_role_claimed, organization_id: organization.id, user_id: user.id, role: "member") }
  subject { described_class.new(organization_role) }

  let(:target) do
    {
      base_url: "/organizations/#{organization.slug}",
      is_admin: false,
      locations: [{id: nil, name: organization.name}],
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
