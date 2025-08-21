# frozen_string_literal: true

# == Schema Information
#
# Table name: locks
#
#  id                 :integer          not null, primary key
#  combination        :string(255)
#  has_combination    :boolean
#  has_key            :boolean          default(TRUE)
#  key_serial         :string(255)
#  lock_model         :string(255)
#  manufacturer_other :string(255)
#  notes              :text
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  lock_type_id       :integer          default(1)
#  manufacturer_id    :integer
#  user_id            :integer
#
# Indexes
#
#  index_locks_on_user_id  (user_id)
#
FactoryBot.define do
  factory :lock_type do
    sequence(:name) { |n| "Lock type #{n}" }
  end

  factory :lock do
    user { FactoryBot.create(:user) }
    manufacturer { FactoryBot.create(:manufacturer) }
    lock_type { FactoryBot.create(:lock_type) }
  end
end
