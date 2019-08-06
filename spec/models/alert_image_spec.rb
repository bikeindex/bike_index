require "rails_helper"

RSpec.describe AlertImage, type: :model do
  describe "after_save commit hooks" do
    it "removes alert_image if no longer current" do
      alert_image = FactoryBot.create(:alert_image, :with_image)
      expect(alert_image.image).to be_present

      alert_image.retired!

      expect(alert_image.image).to be_blank
    end

    it "does not remove alert_image if still current" do
      alert_image = FactoryBot.create(:alert_image, :with_image)
      expect(alert_image.image).to be_present

      alert_image.update(updated_at: Time.current)

      expect(alert_image.image).to be_present
    end
  end

  describe ".retire_all" do
    it "toggles current status and removes images" do
      image1 = FactoryBot.create(:alert_image, :with_image)
      image2 = FactoryBot.create(:alert_image, :with_image)
      FactoryBot.create(:alert_image, :retired)

      expect(AlertImage.current).to match_array([image1, image2])
      expect(AlertImage.current.all? { |i| i.image.present? }).to eq(true)

      AlertImage.retire_all

      expect(AlertImage.current).to be_empty
      expect(AlertImage.current.all? { |i| i.image.blank? }).to eq(true)
    end

    it "retires all within an association scope" do
      stolen_record = FactoryBot.create(:stolen_record)
      image1 = FactoryBot.create(:alert_image, stolen_record: stolen_record)
      image2 = FactoryBot.create(:alert_image, stolen_record: stolen_record)
      FactoryBot.create(:alert_image, :retired, stolen_record: stolen_record)
      image3 = FactoryBot.create(:alert_image)
      FactoryBot.create(:alert_image, :retired)

      current_alert_images = stolen_record.alert_images.current
      expect(current_alert_images.pluck(:id)).to match_array([image1.id, image2.id])
      expect(AlertImage.current.pluck(:id)).to match_array([image1, image2, image3].map(&:id))

      stolen_record.alert_images.retire_all

      expect(current_alert_images.pluck(:id)).to be_empty
      expect(AlertImage.current.pluck(:id)).to match_array([image3.id])
    end
  end

  describe ".current" do
    it "returns images marked as current" do
      image1 = FactoryBot.create(:alert_image)
      FactoryBot.create(:alert_image, :retired)
      image3 = FactoryBot.create(:alert_image)
      expect(AlertImage.current).to match_array([image1, image3])
    end

    it "subsets association results" do
      stolen_record = FactoryBot.create(:stolen_record)
      image1 = FactoryBot.create(:alert_image, stolen_record: stolen_record)
      image2 = FactoryBot.create(:alert_image, stolen_record: stolen_record)
      FactoryBot.create(:alert_image, :retired, stolen_record: stolen_record)
      FactoryBot.create(:alert_image)
      FactoryBot.create(:alert_image, :retired)
      expect(stolen_record.alert_images.current).to match_array([image1, image2])
    end
  end

  describe "#retired?" do
    it "negates current status" do
      old_image = FactoryBot.build_stubbed(:alert_image, :retired)
      expect(old_image).to be_retired

      curr_image = FactoryBot.build_stubbed(:alert_image)
      expect(curr_image).to_not be_retired
    end
  end
end
