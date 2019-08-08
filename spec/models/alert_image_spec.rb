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
