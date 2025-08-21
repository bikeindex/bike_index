# == Schema Information
#
# Table name: alert_images
#
#  id               :integer          not null, primary key
#  image            :string
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  stolen_record_id :integer          not null
#
# Indexes
#
#  index_alert_images_on_stolen_record_id  (stolen_record_id)
#
# Foreign Keys
#
#  fk_rails_...  (stolen_record_id => stolen_records.id)
#
require "rails_helper"

RSpec.describe AlertImage, type: :model do
  describe "before_destroy commit hooks" do
    it "removes alert_image before destroy" do
      alert_image = FactoryBot.create(:alert_image, :with_image)
      expect(alert_image.image).to be_present

      alert_image.destroy

      expect(alert_image.image).to be_blank
    end
  end
end
