# == Schema Information
#
# Table name: hot_sheets
#
#  id                :bigint           not null, primary key
#  delivery_status   :string
#  recipient_ids     :jsonb
#  sheet_date        :date
#  stolen_record_ids :jsonb
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  organization_id   :bigint
#
# Indexes
#
#  index_hot_sheets_on_organization_id  (organization_id)
#
FactoryBot.define do
  factory :hot_sheet do
    organization { FactoryBot.create(:organization) }
    sheet_date { Time.current.to_date }
  end
end
