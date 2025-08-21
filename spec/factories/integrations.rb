# frozen_string_literal: true

# == Schema Information
#
# Table name: integrations
#
#  id            :integer          not null, primary key
#  access_token  :text
#  information   :text
#  provider_name :string(255)
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  user_id       :integer
#
# Indexes
#
#  index_integrations_on_user_id  (user_id)
#
FactoryBot.define do
  factory :integration do
    access_token { "12345teststststs" }
  end
end
