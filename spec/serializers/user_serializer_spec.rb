# == Schema Information
#
# Table name: users
#
#  id                                 :integer          not null, primary key
#  address_set_manually               :boolean          default(FALSE)
#  admin_options                      :jsonb
#  alert_slugs                        :jsonb
#  auth_token                         :string(255)
#  avatar                             :string(255)
#  banned                             :boolean          default(FALSE), not null
#  can_send_many_stolen_notifications :boolean          default(FALSE), not null
#  city                               :string
#  confirmation_token                 :string(255)
#  confirmed                          :boolean          default(FALSE), not null
#  deleted_at                         :datetime
#  description                        :text
#  developer                          :boolean          default(FALSE), not null
#  email                              :string(255)
#  instagram                          :string
#  last_login_at                      :datetime
#  last_login_ip                      :string
#  latitude                           :float
#  longitude                          :float
#  magic_link_token                   :text
#  my_bikes_hash                      :jsonb
#  name                               :string(255)
#  neighborhood                       :string
#  no_address                         :boolean          default(FALSE)
#  no_non_theft_notification          :boolean          default(FALSE)
#  notification_newsletters           :boolean          default(FALSE), not null
#  notification_unstolen              :boolean          default(TRUE)
#  partner_data                       :jsonb
#  password                           :text
#  password_digest                    :string(255)
#  phone                              :string(255)
#  preferred_language                 :string
#  show_bikes                         :boolean          default(FALSE), not null
#  show_instagram                     :boolean          default(FALSE)
#  show_phone                         :boolean          default(TRUE)
#  show_twitter                       :boolean          default(FALSE), not null
#  show_website                       :boolean          default(FALSE), not null
#  street                             :string
#  superuser                          :boolean          default(FALSE), not null
#  terms_of_service                   :boolean          default(FALSE), not null
#  time_single_format                 :boolean          default(FALSE)
#  title                              :text
#  token_for_password_reset           :text
#  twitter                            :string(255)
#  username                           :string(255)
#  vendor_terms_of_service            :boolean
#  when_vendor_terms_of_service       :datetime
#  zipcode                            :string(255)
#  created_at                         :datetime         not null
#  updated_at                         :datetime         not null
#  address_record_id                  :bigint
#  country_id                         :integer
#  state_id                           :integer
#  stripe_id                          :string(255)
#
# Indexes
#
#  index_users_on_address_record_id         (address_record_id)
#  index_users_on_auth_token                (auth_token)
#  index_users_on_token_for_password_reset  (token_for_password_reset)
#
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
      locations: [{id: nil, name: organization.name}],
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
      memberships: [target_organization_role]
    }
  end
  it "renders" do
    expect(subject.as_json(root: false)).to eq target
  end
end
