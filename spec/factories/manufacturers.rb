# == Schema Information
#
# Table name: manufacturers
#
#  id                 :integer          not null, primary key
#  close_year         :integer
#  description        :text
#  frame_maker        :boolean
#  logo               :string(255)
#  logo_source        :string(255)
#  motorized_only     :boolean          default(FALSE)
#  name               :string(255)
#  notes              :text
#  open_year          :integer
#  priority           :integer
#  secondary_slug     :string
#  slug               :string(255)
#  total_years_active :string(255)
#  twitter_name       :string
#  website            :string(255)
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#
FactoryBot.define do
  factory :manufacturer do
    sequence(:name) { |n| "Manufacturer #{n}" }
    frame_maker { true }
  end
end
