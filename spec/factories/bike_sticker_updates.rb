# == Schema Information
#
# Table name: bike_sticker_updates
#
#  id                  :bigint           not null, primary key
#  creator_kind        :integer
#  failed_claim_errors :text
#  kind                :integer
#  organization_kind   :integer
#  update_number       :integer
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  bike_id             :bigint
#  bike_sticker_id     :bigint
#  bulk_import_id      :bigint
#  export_id           :bigint
#  organization_id     :bigint
#  user_id             :bigint
#
# Indexes
#
#  index_bike_sticker_updates_on_bike_id          (bike_id)
#  index_bike_sticker_updates_on_bike_sticker_id  (bike_sticker_id)
#  index_bike_sticker_updates_on_bulk_import_id   (bulk_import_id)
#  index_bike_sticker_updates_on_export_id        (export_id)
#  index_bike_sticker_updates_on_organization_id  (organization_id)
#  index_bike_sticker_updates_on_user_id          (user_id)
#
FactoryBot.define do
  factory :bike_sticker_update do
    bike_sticker { FactoryBot.create(:bike_sticker_claimed) }
    user { bike_sticker.user }
    bike { bike_sticker.bike }
  end
end
