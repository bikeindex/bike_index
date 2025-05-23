# frozen_string_literal: true

require "rails_helper"

RSpec.describe HeaderTags::Component, type: :component do
  let(:options) { {page_title:, page_obj:, controller_name:, controller_namespace:, action_name:, request_url:, organization_name:} }
  let(:request_url) { "https://test.com" }
  let(:page_title) { nil }
  let(:page_obj) { nil }
  let(:organization_name) { nil }
  let(:controller_namespace) { nil }
  let(:action_name) { "index" }
  let(:component) { render_inline(described_class.new(**options)) }
  let(:default_description) { "The best bike registry: Simple, secure and free." }

  # Add tests for:
  # - page title for bikes edit
  # - page title for bike_versions edit
  # - page title for bikes edit

  def expect_matching_tags(title:, description:, image: :default, published_at: nil, modified_at: nil, updated_at: nil)
    expect(component.css("title")).to have_text title

    expect(component.css('meta[name="description"]').first["content"]).to eq description
    expect(component.css('[property="og:description"]').first["content"]).to eq description
    expect(component.css('[name="twitter:description"]').first["content"]).to eq description
    expect(component.css('[name="twitter:card"]').first["content"]).to eq "summary_large_image"

    if published_at.present?
      expect(component.css('[property="article:published_time"]').first["content"]).to eq published_at.iso8601(0)
    else
      expect(component.css('[property="article:published_time"]')).to be_blank
    end
    if modified_at.present?
      expect(component.css('[property="article:modified_time"]').first["content"]).to eq modified_at.iso8601(0)
    else
      expect(component.css('[property="article:modified_time"]')).to be_blank
    end
    if updated_at.present?
      expect(component.css('[property="og:updated_time"]').first["content"]).to eq updated_at.utc.iso8601(0)
    else
      expect(component.css('[property="og:updated_time"]')).to be_blank
    end

    expect_matching_image_tags(image)
  end

  def expect_matching_image_tags(image = :default)
    # return if image == false
    if image == :default
      page_image = "/opengraph.png"
      twitter_image = "/opengraph.png"
    elsif image.is_a?(Hash)
      page_image = image[:page_image]
      twitter_image = image[:twitter_image]
    else
      page_image = image
      twitter_image = image
    end
    expect(component.css('[property="og:image"]').first["content"]).to eq page_image
    expect(component.css('[name="twitter:image"]').first["content"]).to eq twitter_image
  end

  context "welcome controller" do
    let(:controller_name) { "welcome" }

    it "renders" do
      expect(component).to be_present
      expect(component.css("title")).to have_text "Bike Index - Bike registration that works"
      expect(component.css('meta[name="description"]').first["content"]).to eq default_description
      expect(component.css('[property="og:image:height"]').first["content"]).to eq "630"
      expect(component.css('[property="og:image:width"]').first["content"]).to eq "1200"
    end
    context "choose registration" do
      let(:action_name) { "choose_registration" }
      let(:target_description) do
        "Register a bike on Bike Index quickly, easily and for free. Create a permanent verified record of your bike to protect it."
      end

      it "renders" do
        expect(component).to be_present
        expect(component.css("title")).to have_text "Register a bike!"
        expect(component.css('meta[name="description"]').first["content"]).to eq target_description
      end
    end
  end

  context "info" do
    let(:controller_name) { "info" }
    let(:action_name) { "about" }

    it "renders" do
      expect(component).to be_present
      expect(component.css("title")).to have_text "About Bike Index"
      expect(component.css('meta[name="description"]').first["content"]).to eq "Why we made Bike Index and who we are"
      expect(component.to_s).to match('<meta http-equiv="Content-Language" content="en">')
    end

    context "locale: nl" do
      before { I18n.locale = :nl }
      after { I18n.locale = I18n.default_locale }

      it "renders" do
        expect(component).to be_present
        expect(component.css("title")).to have_text "Bike Index - de fietsregistratie die werkt"
        expect(component.css('meta[name="description"]').first["content"]).to eq "Waarom we Bike Index hebben gemaakt en wie we zijn"
        expect(component.to_s).to match('<meta http-equiv="Content-Language" content="nl">')
      end
    end
  end

  context "admin" do
    let(:controller_namespace) { "admin" }
    let(:controller_name) { "dashboard" }
    it "renders" do
      expect(component).to be_present
      expect(component.css("title")).to have_text "🧰 Dashboard"
      expect(component.css('meta[name="description"]').first["content"]).to eq default_description
    end
  end

  context "organized" do
    let(:controller_namespace) { "organized" }
    let(:controller_name) { "bikes" }
    let(:organization_name) { "PSU" }
    it "renders" do
      expect(component).to be_present
      expect(component.css("title")).to have_text "PSU Bikes"
      expect(component.css('meta[name="description"]').first["content"]).to eq default_description
    end
  end

  context "embed" do
    let(:controller_name) { "organizations" }
    let(:action_name) { "embed" }
    let(:organization_name) { "Hush Money Bikes" }
    let(:title) { "Register a bike with #{organization_name}" }
    let(:description) do
      "Embedable #{organization_name} Bike Index registration form. Register your bike for free, right now"
    end
    it "renders" do
      expect(component).to be_present
      expect_matching_tags(title:, description:)
    end

    context "embed_extended" do
      let(:action_name) { "embed_extended" }
      it "renders" do
        expect_matching_tags(title:, description:)
      end
    end

    context "reg_embed" do
      let(:controller_name) { "registrations" }
      it "renders" do
        expect_matching_tags(title:, description:)
      end
    end
  end

  context "news controller" do
    let(:controller_name) { "news" }
    it "renders with atom feed" do
      expect(component.css('link[type="application/atom+xml"]').first["href"]).to eq "http://test.host/news.atom"
    end
    describe "show" do
      let(:action_name) { "show" }
      let(:target_time) { (Time.current - 1.hour).utc }
      # Have to create user so it creates a path for the user
      let(:user) { FactoryBot.create(:user, name: "John", twitter: "stolenbikereg") }
      let(:title) { "Cool blog" }
      let(:page_obj) do
        FactoryBot.build(:blog,
          title:,
          description_abbr: "Bike Index did something cool",
          published_at: target_time,
          updated_at: target_time,
          user: user,
          canonical_url: canonical_url)
      end
      let(:canonical_url) { nil }
      let(:target_url) { "http://something.com" }
      context "index image present" do
        before do
          page_obj.set_title_slug
          allow(page_obj).to receive(:index_image) { target_url }
          allow(page_obj).to receive(:index_image_lg) { target_url }
        end
        it "adds the index image and the tags we want" do
          page_obj.secondary_title = "Another title for cool stuff"

          expect(component.css('link[type="application/atom+xml"]').first["href"]).to eq "http://test.host/news.atom"

          expect_matching_tags(title: "Cool blog", description: "Bike Index did something cool",
            image: target_url, published_at: target_time, modified_at: target_time)

          expect(component.css('link[rel="author"]').first["href"]).to eq Rails.application.routes.url_helpers.user_path(user)

          expect(component.css('[property="og:type"]').first["content"]).to eq "article"
          expect(component.css('[name="twitter:creator"]').first["content"]).to eq "@stolenbikereg"

          expect(component.css('[property="og:url"]').first["content"]).to eq request_url
          expect(component.css('link[rel="canonical"]').first["href"]).to eq request_url
        end
        context "canonical_url" do
          let(:canonical_url) { "https://somewhereelse.com" }
          it "doesn't include creator" do
            expect(component.css('[property="og:url"]').first["content"]).to eq request_url
            expect(component.css('link[rel="canonical"]').first["href"]).to eq canonical_url
          end
        end
      end
      context "public_image present" do
        let(:public_image) { PublicImage.new }
        let(:title) { "Cool blog & something cooler" }
        before do
          page_obj.set_title_slug
          allow(public_image).to receive(:image_url) { target_url }
          allow(page_obj).to receive(:public_images) { [public_image] }
          allow(page_obj).to receive(:index_image_lg) { target_url }
        end
        it "adds the public image we want" do
          expect_matching_tags(title: title, description: "Bike Index did something cool",
            image: target_url, published_at: target_time, modified_at: target_time)

          expect(component.css('[property="og:image:height"]')).to be_blank
        end
      end
      describe "info post" do
        let(:controller_name) { "info" }
        before do
          page_obj.kind = "info"
          page_obj.set_title_slug
        end
        it "returns the info tags" do
          expect(component.css('link[type="application/atom+xml"]').any?).to be_falsey

          expect_matching_tags(title: "Cool blog", description: "Bike Index did something cool",
            published_at: target_time, modified_at: target_time)

          expect(component.css('link[rel="author"]').first["href"]).to eq Rails.application.routes.url_helpers.user_path(user)

          expect(component.css('[property="og:type"]').first["content"]).to eq "article"
          expect(component.css('[name="twitter:creator"]').first["content"]).to eq "@stolenbikereg"

          expect(component.css('[property="og:url"]').first["content"]).to eq request_url
          expect(component.css('link[rel="canonical"]').first["href"]).to eq request_url
        end
      end
    end
  end

  describe "bikes_header_tags" do
    let(:controller_name) { "bikes" }
    let(:bike) { Bike.new(status: "status_stolen") }
    let(:target_time) { Time.current - 2.days }
    let(:page_obj) { bike }
    let(:mnfg_name) { bike.manufacturer.short_name.to_s }

    describe "show" do
      let(:action_name) { "show" }
      let(:bike) { FactoryBot.create(:bike, frame_model: "Something special", year: 1969, description: "Cool description", stock_photo_url:) }
      let(:title) { "1969 #{mnfg_name} Something special" }
      let(:description) { "#{bike.primary_frame_color.name} #{title}, serial: #{bike.serial_number.upcase}. Cool description." }
      let(:stock_photo_url) { "http://something.com" }
      it "returns the bike name on Show" do
        expect(bike.title_string).to eq title
        bike.update_column :updated_at, target_time

        expect_matching_tags(title:, description:, image: stock_photo_url, updated_at: target_time)
        expect(component.css('link[rel="author"]')).to be_blank

        expect(component.css('[property="og:type"]')).to be_blank
        expect(component.css('[name="twitter:creator"]').first["content"]).to eq "@bikeindex"

        expect(component.css('[property="og:url"]').first["content"]).to eq request_url
        expect(component.css('link[rel="canonical"]').first["href"]).to eq request_url
      end
      context "public_image" do
        let!(:public_image) { FactoryBot.create(:public_image, filename: "bike-#{bike.id}.jpg", imageable: bike) }
        before do
          bike.reload.save
          # bike.reload
        end
        it "returns expected thing" do
          expect_matching_tags(title:, description:, image: public_image.image_url(:large), updated_at: bike.updated_at)
        end
      end
      context "stolen" do
        let(:bike) { FactoryBot.create(:stolen_bike_in_chicago) }
        let(:title) { "Stolen #{mnfg_name}" }
        let(:description) do
          "#{bike.primary_frame_color.name} #{mnfg_name}, serial: #{bike.serial_number.upcase}. " \
          "Stolen: #{Time.current.strftime("%Y-%m-%d")}, from: Chicago, IL 60608, US"
        end
        it "returns expected things" do
          expect(bike.reload.current_stolen_record.address).to eq "Chicago, IL 60608, US"

          expect_matching_tags(title:, description:, updated_at: bike.updated_at)
        end
        context "with attached image" do
          let!(:public_image) { FactoryBot.create(:public_image, imageable: bike, image: File.open(image_path)) }
          let(:stolen_record) { bike.current_stolen_record }
          let(:image_path) { Rails.root.join("spec/fixtures/bike_photo-landscape.jpeg") }
          before { Images::StolenProcessor.update_alert_images(stolen_record) }
          let(:target_images) do
            {
              page_image: Rails.application.routes.url_helpers.rails_blob_url(stolen_record.image_opengraph),
              twitter_image: Rails.application.routes.url_helpers.rails_blob_url(stolen_record.image_opengraph)
            }
          end
          it "returns expected" do
            expect(stolen_record.reload.images_attached?).to be_truthy

            expect_matching_tags(title:, image: target_images, description:, updated_at: bike.updated_at)
            expect(component.css('[property="og:image:height"]').first["content"]).to eq "630"
            expect(component.css('[property="og:image:width"]').first["content"]).to eq "1200"
          end
        end
      end
      context "found" do
        let!(:impound_record) { FactoryBot.create(:impound_record, :in_nyc, bike: bike) }
        let(:description) do
          "#{bike.primary_frame_color.name} #{title}, serial: Hidden. Cool description. " \
          "Found: #{Time.current.strftime("%Y-%m-%d")}, in: New York, NY 10007, US"
        end
        let(:title_extended) { "Found #{title}" }
        it "returns expected things" do
          expect(bike.reload.current_impound_record.address).to eq "New York, NY 10007"
          expect(bike.status_humanized).to eq "found"
          expect(bike.title_string).to eq title
          expect_matching_tags(title: title_extended, description:, image: stock_photo_url, updated_at: bike.updated_at)
        end
      end
      context "impounded" do
        let(:parking_notification) { FactoryBot.create(:parking_notification_organized, :in_edmonton, bike: bike, use_entered_address: true) }
        let(:organization) { parking_notification.organization }
        let(:impound_record) { FactoryBot.create(:impound_record_with_organization, bike: bike, parking_notification: parking_notification, organization: organization) }
        let(:title_extended) { "Impounded #{title}" }
        let(:description) do
          "#{bike.primary_frame_color.name} #{title}, serial: Hidden. Cool description. " \
          "Impounded: #{Time.current.strftime("%Y-%m-%d")}, in: Edmonton, AB T6G 2B3, CA"
        end
        it "returns expected things" do
          expect(parking_notification.reload.address).to eq "9330 Groat Rd NW, Edmonton, AB T6G 2B3, CA"
          impound_record.reload
          expect(bike.reload.current_impound_record.address).to eq "Edmonton, AB T6G 2B3, CA"
          expect(bike.status_humanized).to eq "impounded"

          expect_matching_tags(title: title_extended, description:, image: stock_photo_url, updated_at: bike.updated_at)
        end
      end
      #   context "twitter present and shown" do
      #     it "has twitter creator if present and shown" do
      #       user = User.new(twitter: "coolio", show_twitter: true)
      #       allow(bike).to receive(:owner).and_return(user)
      #       @bike = bike # So that it's assigned in the helper
      #       header_tags = helper.bikes_header_tags
      #       expect(header_tags.find { |t| t && t.include?("twitter:creator") }).to match "@coolio"
      #     end
      #   end
      #   context "twitter present and not shown" do
      #     it "doesn't include twitter creator" do
      #       user = User.new(twitter: "coolio")
      #       allow(bike).to receive(:owner).and_return(user)
      #       @bike = bike # So that it's assigned in the helper
      #       header_tags = helper.bikes_header_tags
      #       expect(header_tags.find { |t| t && t.include?("twitter:creator") }).to match "@bikeindex"
      #     end
      #   end
    end
  end
end
