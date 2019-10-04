FactoryBot.define do
  factory :external_registry_bike,
          class: "ExternalRegistryBikes::VerlorenOfGevondenBike" do
    external_id { 10.times.map { rand(10) }.join }
    serial_number { 10.times.map { rand(10) }.join }
    country { Country.netherlands }
  end
end
