require "rails_helper"

RSpec.describe AlertImageGenerator do
  describe ".generate_image" do
    it "writes the alert image to the given output path" do
      output_location = ApplicationUploader.cache_dir.join("bike1-alert.jpg")
      FileUtils.rm_rf(output_location)

      AlertImageGenerator.generate_image(
        bike_image_path: Rails.root.join("spec/fixtures/bike.jpg"),
        bike_url: "bikeindex.org/bikes/1",
        bike_location: "New City, OR",
        output_path: output_location,
      )

      expect(File.exist?(output_location)).to eq(true)
    end
  end
end
