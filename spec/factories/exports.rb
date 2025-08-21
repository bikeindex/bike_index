# == Schema Information
#
# Table name: exports
#
#  id              :integer          not null, primary key
#  file            :text
#  file_format     :integer          default("csv")
#  kind            :integer          default("organization")
#  options         :jsonb
#  progress        :integer          default("pending")
#  rows            :integer
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  organization_id :integer
#  user_id         :integer
#
# Indexes
#
#  index_exports_on_organization_id  (organization_id)
#  index_exports_on_user_id          (user_id)
#
FactoryBot.define do
  factory :export do
    kind { "stolen" } # organizations is default kind, but requires organization so I'm not using it
    factory :export_organization do
      kind { "organization" }
      organization { FactoryBot.create(:organization) }
      factory :export_avery do
        avery_export { true }
      end
    end
  end
end
