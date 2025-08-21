# == Schema Information
#
# Table name: content_tags
#
#  id          :bigint           not null, primary key
#  description :text
#  name        :string
#  priority    :integer
#  slug        :string
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#
FactoryBot.define do
  factory :content_tag do
    sequence(:name) { |n| "Cool tag #{n}" }
    priority { 1 }
  end
end
