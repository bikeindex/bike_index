# frozen_string_literal: true

# == Schema Information
#
# Table name: blogs
#
#  id               :integer          not null, primary key
#  body             :text
#  body_abbr        :text
#  canonical_url    :string
#  description_abbr :text
#  index_image      :string(255)
#  index_image_lg   :string(255)
#  is_info          :boolean          default(FALSE)
#  is_listicle      :boolean          default(FALSE), not null
#  kind             :integer          default("blog")
#  language         :integer          default("en"), not null
#  old_title_slug   :string(255)
#  published        :boolean
#  published_at     :datetime
#  secondary_title  :text
#  title            :text
#  title_slug       :string(255)
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  index_image_id   :integer
#  user_id          :integer
#
FactoryBot.define do
  factory :blog do
    user { FactoryBot.create(:user) }
    body { "Some sweet blog content that everyone loves" }
    sequence(:title) { |n| "Blog title #{n}" }

    trait :published do
      published { true }
    end

    trait :dutch do
      language { "nl" }
    end
  end
end
