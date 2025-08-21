# == Schema Information
#
# Table name: organizations
#
#  id                              :integer          not null, primary key
#  access_token                    :string(255)
#  api_access_approved             :boolean          default(FALSE), not null
#  approved                        :boolean          default(TRUE)
#  ascend_name                     :string
#  available_invitation_count      :integer          default(10)
#  avatar                          :string(255)
#  child_ids                       :jsonb
#  deleted_at                      :datetime
#  direct_unclaimed_notifications  :boolean          default(FALSE)
#  enabled_feature_slugs           :jsonb
#  graduated_notification_interval :bigint
#  is_paid                         :boolean          default(FALSE), not null
#  kind                            :integer
#  landing_html                    :text
#  lightspeed_register_with_phone  :boolean          default(FALSE)
#  location_latitude               :float
#  location_longitude              :float
#  lock_show_on_map                :boolean          default(FALSE), not null
#  manual_pos_kind                 :integer
#  name                            :string(255)
#  opted_into_theft_survey_2023    :boolean          default(FALSE)
#  passwordless_user_domain        :string
#  pos_kind                        :integer          default("no_pos")
#  previous_slug                   :string
#  regional_ids                    :jsonb
#  registration_field_labels       :jsonb
#  search_radius_miles             :float            default(50.0), not null
#  short_name                      :string(255)
#  show_on_map                     :boolean
#  slug                            :string(255)      not null
#  spam_registrations              :boolean          default(FALSE)
#  website                         :string(255)
#  created_at                      :datetime         not null
#  updated_at                      :datetime         not null
#  auto_user_id                    :integer
#  manufacturer_id                 :bigint
#  parent_organization_id          :integer
#
# Indexes
#
#  index_organizations_on_location_latitude_and_location_longitude  (location_latitude,location_longitude)
#  index_organizations_on_manufacturer_id                           (manufacturer_id)
#  index_organizations_on_parent_organization_id                    (parent_organization_id)
#  index_organizations_on_slug                                      (slug) UNIQUE
#
class OrganizationSerializer < ApplicationSerializer
  attributes :name, :website, :kind, :slug
  has_many :locations
end
