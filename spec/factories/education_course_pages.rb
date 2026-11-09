FactoryBot.define do
  factory :education_course_page do
    education_course
    sequence(:listing_order) { |n| n }
    title { "Safety check" }
    body { "<ul><li>point one</li><li>point two</li></ul>" }
  end
end
