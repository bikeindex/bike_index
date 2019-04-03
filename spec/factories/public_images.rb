FactoryBot.define do
  factory :public_image do |u|
    u.image { File.open(File.join(Rails.root, "spec", "fixtures", "bike.jpg")) }
    imageable { FactoryBot.create(:bike) }
  end
end
