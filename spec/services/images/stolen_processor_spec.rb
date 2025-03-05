require "rails_helper"
require "chunky_png" # For image comparison

RSpec.describe Images::StolenProcessor do
  let(:location_text) { "San Francisco, CA" }

  def expect_images_to_match(generated, target, tolerance: 0.001)
    actual = ChunkyPNG::Image.from_file(generated)
    expected = ChunkyPNG::Image.from_file(target)

    # Calculate image difference score
    diff = 0
    actual.height.times do |y|
      actual.width.times do |x|
        diff += 1 unless actual[x, y] == expected[x, y]
      end
    end

    # Allow a small tolerance (e.g., 0.1% of pixels can be different)
    max_diff = (actual.width * actual.height) * tolerance
    expect(diff).to be <= max_diff
  end

  describe "application variant processor" do
    it "vips" do
      expect(Bikeindex::Application.config.active_storage.variant_processor).to eq :vips
    end
  end

  describe "update_alert_images" do
    let(:stolen_record) { FactoryBot.create(:stolen_record) }
    let(:image) { Rails.root.join("spec", "fixtures", "bike_photo-landscape.jpeg") }

    it "attaches the image" do
      expect(stolen_record.reload.image_four_by_five.attached?).to be_falsey
      described_class.update_alert_images(stolen_record, image:)

      expect(stolen_record.reload.image_four_by_five.attached?).to be_truthy
      expect(stolen_record.image_square.attached?).to be_truthy
      expect(stolen_record.image_landscape.attached?).to be_truthy

      # and calling it again removes the images (since the stolen record has no actual images)
      described_class.update_alert_images(stolen_record)

      expect(stolen_record.reload.image_four_by_five.attached?).to be_falsey
      expect(stolen_record.image_square.attached?).to be_falsey
      expect(stolen_record.image_landscape.attached?).to be_falsey
    end
  end

  describe "#stolen_record_location" do
    let(:state) { FactoryBot.create(:state_california) }
    let(:location_attrs) { {state: state, country: Country.united_states, street: "100 W 1st St", city: "Los Angeles", zipcode: "90021", latitude: 34.05223, longitude: -118.24368} }
    context "stolen record with a location" do
      let(:stolen_record) { StolenRecord.new(location_attrs) }
      it "returns the stolen record location" do
        expect(stolen_record.to_coordinates).to eq([location_attrs[:latitude], location_attrs[:longitude]])
        expect(described_class.send(:stolen_record_location, stolen_record)).to eq("Los Angeles, CA")
      end
    end
    context "stolen_record without street, zipcode or city" do
      let(:stolen_record) { FactoryBot.create(:stolen_record, location_attrs.slice(:country, :state, :latitude, :longitude).merge(skip_geocoding: false)) }
      it "returns without" do
        expect(stolen_record.to_coordinates).to eq([nil, nil])
        expect(described_class.send(:stolen_record_location, stolen_record)).to be_blank
      end
    end
    context "Edmonton" do
      let(:location_attrs) { {street: "7935 Gateway Blvd", city: "Edmonton", zipcode: "T6E 3X8", latitude: 53.515072, longitude: -113.494412, state: nil, country: Country.canada} }
      let(:stolen_record) { FactoryBot.create(:stolen_record, location_attrs.merge(skip_geocoding: true)) }
      it "returns edmonton" do
        stolen_record.reload
        expect(stolen_record.to_coordinates).to eq([location_attrs[:latitude], location_attrs[:longitude]])
        expect(described_class.send(:stolen_record_location, stolen_record)).to eq("Edmonton, Canada")
      end
    end
  end

  describe "generate_alert" do
    let(:image) { Rails.root.join("spec/fixtures/bike_photo-landscape.jpeg") }
    let(:target_image) { Rails.root.join("spec", "fixtures", generated_fixture_name) }
    let(:generated_image) do
      described_class.send(:generate_alert, template:, image:, location_text:, convert: "png")
    end
    # If the image generation updates, use this to save the updated image:
    # before { `mv #{generated_image.path} spec/fixtures/#{generated_fixture_name}` }

    context "with template: four_by_five" do
      let(:template) { :four_by_five }
      let(:generated_fixture_name) { "alert-4x5-landscape.png" }

      it "generates an image matching target" do
        expect_images_to_match(generated_image, target_image)
      end

      context "with a portrait image" do
        let(:image) { Rails.root.join("spec/fixtures/bike_photo-portrait.jpeg") }
        let(:generated_fixture_name) { "alert-4x5-portrait.png" }

        it "generates an image matching target" do
          expect_images_to_match(generated_image, target_image)
        end
      end
    end

    context "with template: square" do
      let(:template) { :square }
      let(:generated_fixture_name) { "alert-square-landscape.png" }

      it "generates an image matching target" do
        expect_images_to_match(generated_image, target_image)
      end

      context "with a portrait image" do
        let(:image) { Rails.root.join("spec/fixtures/bike_photo-portrait.jpeg") }
        let(:generated_fixture_name) { "alert-square-portrait.png" }

        it "generates an image matching target" do
          expect_images_to_match(generated_image, target_image)
        end
      end
    end

    context "with template: landscape" do
      let(:template) { :landscape }
      let(:generated_fixture_name) { "alert-landscape-landscape.png" }

      it "creates an image matching target" do
        expect_images_to_match(generated_image, target_image)
      end
    end
  end

  describe "caption_overlay" do
    let(:target_image) { Rails.root.join("spec/fixtures/#{generated_fixture_name}") }
    let(:generated_fixture_name) { "alert_caption.png" }
    let!(:generated_image) { described_class.send(:caption_overlay, location_text).write_to_file(generated_filename) }
    let(:generated_filename) { "tmp/generated_alert_caption.png" }

    it "makes a caption image" do
      # If the caption generation changes, use this to save the updated image:
      # `mv #{generated_filename} spec/fixtures/#{generated_fixture_name}`

      expect_images_to_match(generated_filename, target_image)
    end
  end
end
