# == Schema Information
#
# Table name: bulk_imports
#
#  id              :integer          not null, primary key
#  data            :jsonb
#  file            :text
#  file_cleaned    :boolean          default(FALSE)
#  import_errors   :json
#  is_ascend       :boolean          default(FALSE)
#  kind            :integer
#  no_notify       :boolean          default(FALSE)
#  progress        :integer          default("pending")
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  organization_id :integer
#  user_id         :integer
#
FactoryBot.define do
  factory :bulk_import do
    sequence(:id) { |n| n } # WTF Travis? Travis is blowing up, something to do with different postgres version I'm sure
    file { File.open(Rails.root.join("public", "import_only_required.csv")) }
    user { FactoryBot.create(:user) }
    factory :bulk_import_ascend do
      file { File.open(Rails.root.join("public", "Bike_Index_Reserve_20190207_-_BIKE_LANE_CHIC.csv")) }
      kind { "ascend" }
      organization { nil }
      user { nil }
    end
    factory :bulk_import_success do
      progress { "finished" }
    end
  end
end
