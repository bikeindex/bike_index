# == Schema Information
#
# Table name: impound_configurations
#
#  id                      :bigint           not null, primary key
#  bulk_import_view        :boolean          default(FALSE)
#  display_id_next_integer :integer
#  display_id_prefix       :string
#  email                   :string
#  expiration_period_days  :integer
#  public_view             :boolean          default(FALSE)
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  organization_id         :bigint
#
# Indexes
#
#  index_impound_configurations_on_organization_id  (organization_id)
#
FactoryBot.define do
  factory :impound_configuration do
    organization { FactoryBot.create(:organization_with_organization_features, :with_auto_user, enabled_feature_slugs: "impound_bikes") }
  end
end
