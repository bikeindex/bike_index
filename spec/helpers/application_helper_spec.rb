require "rails_helper"

RSpec.describe ApplicationHelper, type: :helper do
  describe "#show_sharing_links" do
    it "combines twitter, instagram, and website" do
      user = User.new(
        show_website: true,
        my_bikes_hash: {"link_target" => "http://website.com"},
        show_twitter: true,
        twitter: "twitter",
        show_instagram: true,
        instagram: "instagram"
      )
      html = show_sharing_links(user)
      expect(html).to eq("<a href=\"https://twitter.com/twitter\">Twitter</a>, <a href=\"https://instagram.com/instagram\">Instagram</a>, and <a href=\"http://website.com\">Website</a>")
    end
    it "justs return website if no twitter or instagram" do
      user = User.new(show_website: true, my_bikes_hash: {"link_target" => "http://website.com"})
      html = show_sharing_links(user)
      expect(html).to eq("<a href=\"http://website.com\">Website</a>")
    end
    it "handles when no sharing links are present" do
      user = User.new(show_website: false, show_twitter: false, show_instagram: false)
      html = show_sharing_links(user)
      expect(html).to eq("")
    end
  end

  describe "#websiteable" do
    let(:user) { User.new(show_website: true, my_bikes_hash: {"link_target" => "http://website.com"}) }
    it "creates a link if bike owner wants one shown" do
      expect(user.mb_link_target).to eq "http://website.com"
      expect(websiteable(user)).to eq('<a href="http://website.com">Website</a>')
    end
    context "with show_website false" do
      let(:user) { User.new(show_website: false, my_bikes_hash: {"link_target" => "http://website.com"}) }
      it "returns nil" do
        expect(websiteable(user)).to be_nil
      end
    end
    context "with link_title" do
      let(:user) { User.new(show_website: true, my_bikes_hash: {"link_target" => "http://website.com", "link_title" => "stuff"}) }
      it "returns nil" do
        expect(websiteable(user)).to eq('<a href="http://website.com">stuff</a>')
      end
    end
  end

  describe "#twitterable" do
    it "creates a link if bike owner wants one shown" do
      user = User.new
      allow(user).to receive(:show_twitter).and_return(true)
      allow(user).to receive(:twitter).and_return("twitter")
      html = twitterable(user)
      expect(html).to eq('<a href="https://twitter.com/twitter">Twitter</a>')
    end
  end

  describe "attr_list_item" do
    let(:bike) { Bike.new(serial_number: "adasdfasdf") }
    it "returns nil if not there" do
      expect(attr_list_item(bike.mnfg_name, "Manufacturer")).to be_blank
      expect(attr_list_item(" ", "title")).to be_blank
    end
    context "with matching element" do
      let(:target) { "<li><strong class=\"attr-title\">Serial: </strong><span>ADASDFASDF</span></li>" }
      it "returns with the values" do
        expect(attr_list_item(bike.serial_display, "Serial")).to eq target
      end
    end
  end

  describe "body_class" do
    context "organized" do
      before do
        helper.extend(ControllerHelpers)
        helper.extend(Binxtils::ControllerNamespace)
        allow(view).to receive(:controller_name) { "bikes" }
        allow(view).to receive(:controller_namespace) { "organized" }
      end
      it "returns organized-body" do
        expect(helper.body_class).to eq "organized-body"
      end
      context "the register flow" do
        it "adds the gray the flow's page renders on" do
          allow(view).to receive(:controller_name) { "registrations" }
          allow(view).to receive(:action_name) { "new" }
          expect(helper.body_class).to eq "organized-body tw:bg-gray-100 tw:dark:bg-gray-900"
        end
      end
    end
    context "landing_page controller" do
      before { allow(view).to receive(:controller_name) { "landing_pages" } }
      it "returns organized-body" do
        expect(helper.body_class).to eq "landing-page-body"
      end
    end
    context "bikes controller" do
      before do
        helper.extend(ControllerHelpers)
        helper.extend(Binxtils::ControllerNamespace)
        allow(view).to receive(:controller_name) { "bikes" }
        allow(view).to receive(:controller_namespace) { nil }
      end
      it "returns nil" do
        expect(helper.body_class).to be_nil
      end
    end
    context "info controller resources" do
      before do
        allow(view).to receive(:controller_name) { "info" }
        allow(view).to receive(:action_name) { "resources" }
      end
      it "returns kelsey_landing-page-body" do
        expect(helper.body_class).to eq "kelsey_landing-page-body"
      end
    end
  end

  describe "listicle_html" do
    it "returns the html formatted as we want" do
      l = Listicle.new(body: "body", title: "title", image_credits: "credit")
      l.htmlize_content
      html = helper.listicle_html(l)
      target = '<article><div class="listicle-image-credit"><p>credit</p>'
      target << "\n"
      target << '</div><h2 class="list-item-title">title</h2></article><article><p>body</p>'
      target << "\n"
      target << "</article>"
      expect(html).to eq(target)
    end
  end
end
