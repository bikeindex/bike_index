# == Schema Information
#
# Table name: hot_sheet_configurations
#
#  id                         :bigint           not null, primary key
#  is_on                      :boolean          default(FALSE)
#  search_radius_miles        :float
#  send_seconds_past_midnight :integer
#  timezone_str               :string
#  created_at                 :datetime         not null
#  updated_at                 :datetime         not null
#  organization_id            :bigint
#
# Indexes
#
#  index_hot_sheet_configurations_on_organization_id  (organization_id)
#
FactoryBot.define do
  factory :hot_sheet_configuration do
    organization { FactoryBot.create(:organization_with_organization_features, :in_nyc, enabled_feature_slugs: ["hot_sheet"]) }
    send_seconds_past_midnight { 21_600 }
    timezone_str { "America/Los_Angeles" }
    search_radius_miles { 50 }
  end
end
