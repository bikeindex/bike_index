FactoryBot.define do
  factory :sale do
    amount_cents { 100 }
    seller { ownership.user }
    sold_via { :facebook }
    ownership { FactoryBot.create(:bike, :with_ownership_claimed).current_ownership }
  end
end
