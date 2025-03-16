require "rails_helper"
require "chunky_png" # For image comparison

RSpec.describe Images::StolenProcessor do
  let(:location_text) { "San Francisco, CA" }

  def expect_images_to_match(generated, target, tolerance: 0.1)
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
    let(:bike) { stolen_record.bike }
    let!(:public_image) { FactoryBot.create(:public_image, imageable: bike, image: File.open(image)) }
    let(:image) { Rails.root.join("spec/fixtures/bike_photo-landscape.jpeg") }

    it "assigns the public_image" do
      stolen_record.bike.update_column :updated_at, Time.current - 1.hour
      Sidekiq::Job.clear_all
      expect(stolen_record.reload.bike_main_image.id).to eq public_image.id
      expect do
        described_class.update_alert_images(stolen_record)
      end.to change(ActiveStorage::Blob, :count).by 3
      expect(stolen_record.reload.image_four_by_five.attached?).to be_truthy
      expect(stolen_record.image_square.attached?).to be_truthy
      expect(stolen_record.image_landscape.attached?).to be_truthy
      expect(stolen_record.reload.image_four_by_five.blob.metadata["public_image_id"]).to eq public_image.id
      expect(stolen_record.bike.updated_at).to be_within(1).of Time.current
      # No new jobs are enqueued
      expect(StolenBike::AfterStolenRecordSaveJob.jobs.count).to eq 0

      stolen_record.bike.update_column :updated_at, Time.current - 1.hour
      # It doesn't create again
      expect do
        described_class.update_alert_images(stolen_record)
      end.to change(ActiveStorage::Blob, :count).by 0
      expect(stolen_record.reload.images_attached?).to be_truthy
      # It doesn't update the updated_at
      expect(stolen_record.reload.bike.updated_at).to be_within(1).of(Time.current - 1.hour)
      # No new jobs are enqueued
      expect(StolenBike::AfterStolenRecordSaveJob.jobs.count).to eq 0
    end

    context "public_image deleted" do
      it "removes" do
        expect(stolen_record.reload.image_four_by_five.attached?).to be_falsey
        expect do
          described_class.update_alert_images(stolen_record)
        end.to change(ActiveStorage::Blob, :count).by 3

        expect(stolen_record.reload.image_four_by_five.attached?).to be_truthy
        expect(stolen_record.image_square.attached?).to be_truthy
        expect(stolen_record.image_landscape.attached?).to be_truthy

        public_image.destroy
        stolen_record.bike.update_column :updated_at, Time.current - 1.hour
        # Calling it after public_image is deleted, soft deletes the attachments
        expect do
          described_class.update_alert_images(stolen_record)
        end.to change(ActiveStorage::Blob, :count).by 0

        expect(stolen_record.reload.images_attached?).to be_falsey
        expect(stolen_record.bike.updated_at).to be_within(1).of Time.current
      end
    end

    context "passing a public_image" do
      let!(:public_image_2) { FactoryBot.create(:public_image, imageable: bike) }

      it "creates, deletes if the image is deleted" do
      end

      it "doesn't recreate if the image changes" do
      end
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

    context "with template: landscape" do
      let(:template) { :landscape }
      let(:generated_fixture_name) { "alert-landscape-landscape.png" }

      it "creates an image matching target" do
        expect_images_to_match(generated_image, target_image)
      end
    end

    # These tests take a substantial amount of resources and are largely the same
    # - they were useful for building the functionality, and will be useful if it's ever changed -
    # but they don't need to run every CI run
    if !ENV["CI"]
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
    end
  end

  # Ditto the above - this was useful when creating the functionality, but doesn't need to run every CI run
  if !ENV["CI"]
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
end
