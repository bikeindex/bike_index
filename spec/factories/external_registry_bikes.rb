# == Schema Information
#
# Table name: external_registry_bikes
#
#  id                        :integer          not null, primary key
#  category                  :string
#  cycle_type                :string
#  date_stolen               :datetime
#  description               :string
#  external_updated_at       :datetime
#  extra_registration_number :string
#  frame_colors              :string
#  frame_model               :string
#  info_hash                 :jsonb
#  location_found            :string
#  mnfg_name                 :string
#  serial_normalized         :string           not null
#  serial_number             :string           not null
#  status                    :integer
#  type                      :string           not null
#  created_at                :datetime         not null
#  updated_at                :datetime         not null
#  country_id                :integer          not null
#  external_id               :string           not null
#
# Indexes
#
#  index_external_registry_bikes_on_country_id         (country_id)
#  index_external_registry_bikes_on_external_id        (external_id)
#  index_external_registry_bikes_on_serial_normalized  (serial_normalized)
#  index_external_registry_bikes_on_type               (type)
#
FactoryBot.define do
  factory :external_registry_bike,
    class: "ExternalRegistryBike::VerlorenOfGevondenBike" do
    external_id { 10.times.map { rand(10) }.join }
    serial_number { 10.times.map { rand(10) }.join }
    country { Country.netherlands }
  end
end
