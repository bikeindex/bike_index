# frozen_string_literal: true

require "rails_helper"

RSpec.describe HeaderTags::Component, type: :component do
  let(:options) { {page_title:, page_obj:, controller_name:, controller_namespace:, action_name:, request_url:, language:} }
  let(:language) { "en" }
  let(:request_url) { "https://test.com" }
  let(:page_title) { nil }
  let(:page_obj) { nil }
  let(:controller_namespace) { nil }
  let(:action_name) { "index" }
  let(:component) { render_inline(described_class.new(**options)) }

  context "welcome index" do
    let(:controller_name) { "welcome" }
    it "renders" do
      expect(component).to be_present
    end
  end

  context "news controller" do
    let(:controller_name) { "news" }
    it "renders with atom feed" do
      expect(component.css('link[type="application/atom+xml"]').first['href']).to eq "http://test.host/news.atom"
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
          expect(component.css('title')).to have_text "Cool blog"
          expect(component.css('link[rel="author"]').first["href"]).to eq Rails.application.routes.url_helpers.user_path(user)
          expect(component.css('meta[name="description"]').first["content"]).to eq "Bike Index did something cool"
          expect(component.css('[property="og:description"]').first["content"]).to eq "Bike Index did something cool"
          expect(component.css('[name="twitter:description"]').first["content"]).to eq "Bike Index did something cool"

          expect(component.css('[property="og:image"]').first["content"]).to eq target_url
          expect(component.css('[name="twitter:image"]').first["content"]).to eq target_url

          expect(component.css('[property="og:type"]').first["content"]).to eq "article"
          expect(component.css('[name="twitter:creator"]').first["content"]).to eq "@stolenbikereg"

          expect(component.css('[property="article:published_time"]').first["content"]).to eq target_time.iso8601(0)
          expect(component.css('[property="article:modified_time"]').first["content"]).to eq target_time.iso8601(0)

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
          expect(component.css('title')).to have_text title
          expect(component.css('[property="og:image"]').first["content"]).to eq target_url
          expect(component.css('[name="twitter:image"]').first["content"]).to eq target_url
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
          expect(component.css('title')).to have_text "Cool blog"
          expect(component.css('link[rel="author"]').first["href"]).to eq Rails.application.routes.url_helpers.user_path(user)
          expect(component.css('meta[name="description"]').first["content"]).to eq "Bike Index did something cool"
          expect(component.css('[property="og:description"]').first["content"]).to eq "Bike Index did something cool"
          expect(component.css('[name="twitter:description"]').first["content"]).to eq "Bike Index did something cool"

          expect(component.css('[property="og:image"]').first["content"]).to eq "/opengraph.png"
          expect(component.css('[name="twitter:image"]').first["content"]).to eq "/opengraph.png"

          expect(component.css('[property="og:type"]').first["content"]).to eq "article"
          expect(component.css('[name="twitter:creator"]').first["content"]).to eq "@stolenbikereg"

          expect(component.css('[property="article:published_time"]').first["content"]).to eq target_time.iso8601(0)
          expect(component.css('[property="article:modified_time"]').first["content"]).to eq target_time.iso8601(0)

          expect(component.css('[property="og:url"]').first["content"]).to eq request_url
          expect(component.css('link[rel="canonical"]').first["href"]).to eq request_url
        end
      end
    end
  end

  describe "about" do
    let(:controller_name) { "info" }
    let(:action_name) { "about" }
    let(:target_description) { "Why we made Bike Index and who we are" }
    let(:target_time) { Time.at(1740674807) } # 2025-02-27
    it "returns default about header tags" do
      expect(component.css('title')).to have_text "Bike Index - Bike registration that works"

      expect(component.css('link[type="application/atom+xml"]').any?).to be_falsey

      expect(component.css('link[rel="author"]').any?).to be_falsey
      expect(component.css('meta[name="description"]').first["content"]).to eq target_description
      expect(component.css('[property="og:description"]').first["content"]).to eq target_description
      expect(component.css('[name="twitter:description"]').first["content"]).to eq target_description

      expect(component.css('[property="og:image"]').first["content"]).to eq target_url
      expect(component.css('[name="twitter:image"]').first["content"]).to eq target_url

      expect(component.css('[property="og:type"]').first["content"]).to eq "article"
      expect(component.css('[name="twitter:creator"]').first["content"]).to eq "@bikeindex"

      expect(component.css('[property="og:updated_time"]').first["content"]).to eq target_time.iso8601(0)

      expect(component.css('[property="og:url"]').first["content"]).to eq request_url
      expect(component.css('link[rel="canonical"]').first["href"]).to eq request_url
    end
  end
end
