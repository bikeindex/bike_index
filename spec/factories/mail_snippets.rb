# == Schema Information
#
# Table name: mail_snippets
#
#  id                    :integer          not null, primary key
#  body                  :text
#  city                  :string
#  is_enabled            :boolean          default(FALSE), not null
#  is_location_triggered :boolean          default(FALSE), not null
#  kind                  :integer          default("custom")
#  latitude              :float
#  longitude             :float
#  neighborhood          :string
#  proximity_radius      :integer
#  street                :string
#  subject               :text
#  zipcode               :string
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#  country_id            :bigint
#  doorkeeper_app_id     :bigint
#  organization_id       :integer
#  state_id              :bigint
#
# Indexes
#
#  index_mail_snippets_on_country_id         (country_id)
#  index_mail_snippets_on_doorkeeper_app_id  (doorkeeper_app_id)
#  index_mail_snippets_on_organization_id    (organization_id)
#  index_mail_snippets_on_state_id           (state_id)
#
FactoryBot.define do
  factory :mail_snippet do
    kind { MailSnippet.kinds.first }
    is_enabled { true }
    body { "<p>Foo</p>" }
    factory :organization_mail_snippet do
      sequence(:kind) { |n| MailSnippet.organization_snippet_kinds[MailSnippet.organization_snippet_kinds.count % n] }
      organization { FactoryBot.create(:organization) }
    end
  end
end
