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
