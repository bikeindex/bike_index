# == Schema Information
#
# Table name: marketplace_listings
#
#  id                :bigint           not null, primary key
#  amount_cents      :integer
#  condition         :integer
#  currency_enum     :integer
#  description       :text
#  end_at            :datetime
#  item_type         :string
#  latitude          :float
#  longitude         :float
#  price_negotiable  :boolean          default(FALSE)
#  published_at      :datetime
#  status            :integer
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  address_record_id :bigint
#  buyer_id          :bigint
#  item_id           :bigint
#  seller_id         :bigint
#
# Indexes
#
#  index_marketplace_listings_on_address_record_id  (address_record_id)
#  index_marketplace_listings_on_buyer_id           (buyer_id)
#  index_marketplace_listings_on_item               (item_type,item_id)
#  index_marketplace_listings_on_seller_id          (seller_id)
#
FactoryBot.define do
  factory :marketplace_listing do
    buyer { nil }
    item { FactoryBot.create(:bike, :with_primary_activity) }
    seller { item&.user || FactoryBot.create(:user_confirmed) }
    amount_cents { 5_000 }
    condition { "excellent" }

    status { "draft" }

    trait :with_address_record do
      address_record { FactoryBot.build(:address_record, kind: :marketplace_listing, user: seller) }
    end

    trait :for_sale do
      with_address_record
      published_at { Time.current - 1.minute }
      status { :for_sale }
    end

    trait :sold do
      end_at { Time.current - 1.minute }
      published_at { Time.current - 1.week }
      buyer { FactoryBot.create(:user_confirmed) }
      status { :sold }
    end
  end
end
