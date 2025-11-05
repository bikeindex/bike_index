FactoryBot.define do
  factory :item_sale do
    amount_cents { 100 }
    item { FactoryBot.create(:bike, :with_ownership_claimed) }
    seller { FactoryBot.create(:user_confirmed) }
    sold_via { :facebook }
    ownership { item.current_ownership }
  end
end
