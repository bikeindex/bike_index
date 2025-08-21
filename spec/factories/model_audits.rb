# == Schema Information
#
# Table name: model_audits
#
#  id                   :bigint           not null, primary key
#  bikes_count          :integer
#  certification_status :integer
#  cycle_type           :integer
#  frame_model          :string
#  manufacturer_other   :string
#  mnfg_name            :string
#  propulsion_type      :integer
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#  manufacturer_id      :bigint
#
# Indexes
#
#  index_model_audits_on_manufacturer_id  (manufacturer_id)
#
FactoryBot.define do
  factory :model_audit do
    sequence(:frame_model) { |n| "Model #{n}" }
    manufacturer { FactoryBot.create(:manufacturer) }
    propulsion_type { :throttle }
  end
end
