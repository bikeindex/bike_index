FactoryBot.define do
  factory :external_registry_bike do
    external_registry { ExternalRegistry.verloren_of_gevonden }
    external_id { 10.times.map { rand(10) }.join }
    serial_number { 10.times.map { rand(10) }.join }
  end
end
