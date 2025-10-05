# frozen_string_literal: true

FactoryBot.define do
  factory :component do
    bike { FactoryBot.create(:bike) }
    ctype { FactoryBot.create(:ctype) }
  end
end
