# == Schema Information
#
# Table name: stolen_bike_listings
#
#  id                       :bigint           not null, primary key
#  amount_cents             :integer
#  currency_enum            :integer
#  data                     :jsonb
#  frame_model              :text
#  frame_size               :string
#  frame_size_number        :float
#  frame_size_unit          :string
#  group                    :integer
#  line                     :integer
#  listed_at                :datetime
#  listing_order            :integer
#  listing_text             :text
#  manufacturer_other       :string
#  mnfg_name                :string
#  created_at               :datetime         not null
#  updated_at               :datetime         not null
#  bike_id                  :bigint
#  initial_listing_id       :bigint
#  manufacturer_id          :bigint
#  primary_frame_color_id   :bigint
#  secondary_frame_color_id :bigint
#  tertiary_frame_color_id  :bigint
#
# Indexes
#
#  index_stolen_bike_listings_on_bike_id                   (bike_id)
#  index_stolen_bike_listings_on_initial_listing_id        (initial_listing_id)
#  index_stolen_bike_listings_on_manufacturer_id           (manufacturer_id)
#  index_stolen_bike_listings_on_primary_frame_color_id    (primary_frame_color_id)
#  index_stolen_bike_listings_on_secondary_frame_color_id  (secondary_frame_color_id)
#  index_stolen_bike_listings_on_tertiary_frame_color_id   (tertiary_frame_color_id)
#
FactoryBot.define do
  factory :stolen_bike_listing do
    manufacturer { FactoryBot.create(:manufacturer) }
    primary_frame_color { Color.black }
  end
end
