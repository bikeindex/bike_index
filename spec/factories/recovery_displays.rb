# == Schema Information
#
# Table name: recovery_displays
#
#  id               :integer          not null, primary key
#  image            :string(255)
#  link             :string(255)
#  quote            :text
#  quote_by         :string(255)
#  recovered_at     :datetime
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  stolen_record_id :integer
#
# Indexes
#
#  index_recovery_displays_on_stolen_record_id  (stolen_record_id)
#
FactoryBot.define do
  factory :recovery_display do
    quote { "Recovered!" }
    factory :recovery_display_with_stolen_record do
      stolen_record { FactoryBot.create(:stolen_record_recovered) }
    end
  end
end
