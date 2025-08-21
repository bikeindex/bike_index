# == Schema Information
#
# Table name: email_domains
#
#  id                :bigint           not null, primary key
#  data              :jsonb
#  deleted_at        :datetime
#  domain            :string
#  status            :integer          default("permitted")
#  status_changed_at :datetime
#  user_count        :integer
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  creator_id        :bigint
#
# Indexes
#
#  index_email_domains_on_creator_id  (creator_id)
#
FactoryBot.define do
  factory :email_domain do
    creator { FactoryBot.create(:superuser) }
    sequence(:domain) { |n| "@fakedomain-#{n}.com" }
  end
end
