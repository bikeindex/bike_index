FactoryBot.define do
  factory :blog_content_tag do
    blog { FactoryBot.create(:blog) }
    content_tag { FactoryBot.create(:content_tag) }
  end
end
