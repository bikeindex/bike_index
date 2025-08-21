# frozen_string_literal: true

# == Schema Information
#
# Table name: ctypes
#
#  id             :integer          not null, primary key
#  has_multiple   :boolean          default(FALSE), not null
#  image          :string(255)
#  name           :string(255)
#  secondary_name :string(255)
#  slug           :string(255)
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  cgroup_id      :integer
#
FactoryBot.define do
  factory :ctype do
    sequence(:name) { |n| "Component type#{n}" }
    cgroup { FactoryBot.create(:cgroup) }
  end
end
