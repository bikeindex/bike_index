FactoryBot.define do
  factory :public_image do
    sequence(:image) { |i| File.open(ApplicationUploader.cache_dir.join("bike-#{i}.jpg"), "w+") }
    imageable { FactoryBot.create(:bike) }
  end
end
