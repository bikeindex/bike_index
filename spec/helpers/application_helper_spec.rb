require "rails_helper"

RSpec.describe ApplicationHelper, type: :helper do
  describe "phone_link and phone_display" do
    it "displays phone with an area code and country code" do
      expect(phone_display("999 999 9999")).to eq("999-999-9999")
      expect(phone_display("+91 8041505583")).to eq("+91-804-150-5583")
    end
    context "no phone" do
      it "returns empty string if empty" do
        expect(phone_link(nil, class: "phone-number-link")).to eq ""
      end
    end
    context "with extension" do
      let(:target) { '<a href="tel:+11-121-1111 ; 2929222">+11-121-1111 x 2929222</a>' }
      it "returns link" do
        expect(phone_display("+11 1211111 x2929222")).to eq "+11-121-1111 x 2929222"
        expect(phone_link("+11 121 1111 x2929222")).to eq target
      end
    end
    context "passed class" do
      let(:target) { '<a class="phone-number-link" href="tel:777-777-7777 ; 2929222">777-777-7777 x 2929222</a>' }
      it "has class" do
        expect(phone_display("777 777 7777 ext. 2929222")).to eq "777-777-7777 x 2929222"
        expect(phone_link("777 777 7777 ext. 2929222", class: "phone-number-link")).to eq target
      end
    end
  end

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

  describe "active_link" do
    context "without a class" do
      it "returns the link active if it ought to be" do
        allow(view).to receive(:current_page?).and_return(true)
        generated = '<a class=" active" href="http://bikeindex.org">Bike Index about</a>'
        expect(helper.active_link("Bike Index about", "http://bikeindex.org")).to eq generated
      end
    end
    context "match controller true" do
      let(:request) { double("request", url: new_bike_url) }
      before { allow(helper).to receive(:request).and_return(request) }
      it "returns the link active if it is a bikes page" do
        generated = '<a class="seeeeeeee active" id="" href="' + new_bike_url + '">Bike Index bikes page</a>'
        result = helper.active_link("Bike Index bikes page", new_bike_url, match_controller: true, class: "seeeeeeee", id: "")
        expect(result).to eq generated
      end
    end
    context "current with a class" do
      it "returns the link active if it ought to be" do
        allow(view).to receive(:current_page?).and_return(true)
        generated = '<a class="nav-party-link active" id="XXX" href="http://bikeindex.org">Bike Index about</a>'
        result = helper.active_link("Bike Index about", "http://bikeindex.org", class: "nav-party-link", id: "XXX")
        expect(result).to eq generated
      end
    end
  end

  describe "current_page_skeleton" do
    let(:controller_namespace) { nil }

    before do
      helper.extend(ControllerHelpers)
      allow(view).to receive(:controller_namespace) { controller_namespace }
    end

    describe "landing_pages controller" do
      before { allow(view).to receive(:controller_name) { "landing_pages" } }
      context "show (organization landing page)" do
        it "returns nil" do
          allow(view).to receive(:action_name) { "show" }
          expect(helper.current_page_skeleton).to be_nil
        end
      end
      %w[for_law_enfocement for_schools].each do |action|
        context action do
          it "returns nil" do
            allow(view).to receive(:action_name) { action }
            expect(helper.current_page_skeleton).to be_nil
          end
        end
      end
    end
    describe "bikes controller" do
      before { allow(view).to receive(:controller_name) { "bikes" } }
      %w[new create].each do |action|
        context action do
          it "returns nil" do
            allow(view).to receive(:action_name) { action }
            expect(helper.current_page_skeleton).to be_nil
          end
        end
      end
      context "update" do
        it "returns edit_bike_skeleton" do
          allow(view).to receive(:action_name) { "update" }
          expect(helper.current_page_skeleton).to eq "edit_bike_skeleton"
        end
      end
    end
    describe "registrations controller" do
      before { allow(view).to receive(:controller_name) { "registrations" } }
      %w[new].each do |action|
        context action do
          it "returns content_skeleton" do
            allow(view).to receive(:action_name) { action }
            expect(helper.current_page_skeleton).to eq "content_skeleton"
          end
        end
      end
    end
    describe "search registrations controller" do
      let(:controller_namespace) { "search" }
      before { allow(view).to receive(:controller_name) { "registrations" } }
      it "returns nil" do
        allow(view).to receive(:action_name) { "index" }
        expect(helper.current_page_skeleton).to be_nil
      end
    end
    describe "info controller" do
      before { allow(view).to receive(:controller_name) { "info" } }
      %w[about protect_your_bike where serials image_resources resources dev_and_design].each do |action|
        context action do
          it "returns content_skeleton" do
            allow(view).to receive(:action_name) { action }
            expect(helper.current_page_skeleton).to eq "content_skeleton"
          end
        end
      end
      context "support_the_index" do
        it "returns nil" do
          allow(view).to receive(:action_name) { "support_the_index" }
          expect(helper.current_page_skeleton).to be_nil
        end
      end
      %w[terms vendor_terms security privacy].each do |action|
        context action do
          it "returns nil" do
            allow(view).to receive(:action_name) { action }
            expect(helper.current_page_skeleton).to be_nil
          end
        end
      end
    end
    describe "bike edit pages" do
      context "bikes edit" do
        it "returns edit_bike_skeleton" do
          allow(view).to receive(:controller_name) { "edits" }
          allow(view).to receive(:action_name) { "show" }
          expect(helper.current_page_skeleton).to eq "edit_bike_skeleton"
        end
      end
      context "theft_alerts" do
        before { allow(view).to receive(:controller_name) { "theft_alerts" } }
        it "new returns edit_bike_skeleton" do
          allow(view).to receive(:action_name) { "new" }
          expect(helper.current_page_skeleton).to eq "edit_bike_skeleton"
        end
        it "show returns edit_bike_skeleton" do
          allow(view).to receive(:action_name) { "show" }
          expect(helper.current_page_skeleton).to eq "edit_bike_skeleton"
        end
      end
      context "recovery" do
        it "new returns edit_bike_skeleton" do
          allow(view).to receive(:controller_name) { "recovery" }
          allow(view).to receive(:action_name) { "edit" }
          expect(helper.current_page_skeleton).to eq "edit_bike_skeleton"
        end
      end
    end
    describe "news controller" do
      before { allow(view).to receive(:controller_name) { "news" } }
      %w[index show].each do |action|
        context action do
          it "returns content_skeleton" do
            allow(view).to receive(:action_name) { action }
            expect(helper.current_page_skeleton).to eq "content_skeleton"
          end
        end
      end
    end
    describe "payments controller" do
      before { allow(view).to receive(:controller_name) { "payments" } }
      %w[new create].each do |action|
        context action do
          it "returns nil" do
            allow(view).to receive(:action_name) { action }
            expect(helper.current_page_skeleton).to be_nil
          end
        end
      end
    end
    describe "feedbacks controller" do
      before { allow(view).to receive(:controller_name) { "feedbacks" } }
      %w[index].each do |action|
        context action do
          it "returns content_skeleton" do
            allow(view).to receive(:action_name) { action }
            expect(helper.current_page_skeleton).to eq "content_skeleton"
          end
        end
      end
    end
    describe "manufacturers controller" do
      before { allow(view).to receive(:controller_name) { "manufacturers" } }
      %w[index].each do |action|
        context action do
          it "returns nil" do
            allow(view).to receive(:action_name) { action }
            expect(helper.current_page_skeleton).to eq "content_skeleton"
          end
        end
      end
    end
    describe "welcome controller" do
      before { allow(view).to receive(:controller_name) { "welcome" } }
      %w[goodbye].each do |action|
        context action do
          it "returns content_skeleton" do
            allow(view).to receive(:action_name) { action }
            expect(helper.current_page_skeleton).to eq "content_skeleton"
          end
        end
      end
    end
    describe "organizations controller" do
      before { allow(view).to receive(:controller_name) { "organizations" } }
      context "lightspeed_integration" do
        it "returns content_skeleton" do
          allow(view).to receive(:action_name) { "lightspeed_integration" }
          expect(helper.current_page_skeleton).to eq "content_skeleton"
        end
      end
      context "new" do
        it "returns no skeleton" do
          allow(view).to receive(:action_name) { "new" }
          expect(helper.current_page_skeleton).to be_nil
        end
      end
    end
    describe "organized subrouting" do
      let(:controller_namespace) { "organized" }
      context "manage" do
        before { allow(view).to receive(:controller_name) { "manage" } }
        it "returns organized for index" do
          allow(view).to receive(:action_name) { "index" }
          expect(helper.current_page_skeleton).to eq "organized_skeleton"
        end
      end
      context "bikes" do
        before { allow(view).to receive(:controller_name) { "bikes" } }
        it "returns organized for index" do
          allow(view).to receive(:action_name) { "index" }
          expect(helper.current_page_skeleton).to eq "organized_skeleton"
        end
      end
      context "users" do
        before { allow(view).to receive(:controller_name) { "users" } }
        it "returns organized for index" do
          allow(view).to receive(:action_name) { "index" }
          expect(helper.current_page_skeleton).to eq "organized_skeleton"
        end
      end
    end
    describe "stolen controller" do
      before { allow(view).to receive(:controller_name) { "stolen" } }
      %w[index].each do |action|
        context action do
          it "returns nil" do
            allow(view).to receive(:action_name) { action }
            expect(helper.current_page_skeleton).to be_nil
          end
        end
      end
    end
    describe "errors controller" do
      before { allow(view).to receive(:controller_name) { "errors" } }
      %w[bad_request not_found unprocessable_entity server_error unauthorized].each do |action|
        context action do
          it "returns content_skeleton" do
            allow(view).to receive(:action_name) { action }
            expect(helper.current_page_skeleton).to eq "content_skeleton"
          end
        end
      end
    end
  end

  describe "body_class" do
    context "organized_skeleton" do
      it "returns organized-body" do
        expect(helper).to receive(:current_page_skeleton) { "organized_skeleton" }
        expect(helper.body_class).to eq "organized-body"
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
        allow(view).to receive(:controller_name) { "bikes" }
        allow(view).to receive(:controller_namespace) { nil }
      end
      it "returns nil" do
        expect(helper.body_class).to be_nil
      end
    end
  end

  describe "content_page_type" do
    context "info controller" do
      it "returns info active_page" do
        allow(view).to receive(:controller_name).and_return("info")
        allow(view).to receive(:action_name).and_return("dev_and_design")
        expect(helper.content_page_type).to eq "dev_and_design"
      end
    end
    context "news controller" do
      it "returns news index" do
        allow(view).to receive(:controller_name).and_return("news")
        allow(view).to receive(:action_name).and_return("index")
        expect(helper.content_page_type).to eq "news"
      end
    end
    context "bikes controller" do
      let(:request) { double("request", url: new_bike_url) }
      before { allow(helper).to receive(:request).and_return(request) }
      it "returns nil for non-info pages" do
        expect(helper.content_page_type).to be_nil
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

  describe "sortable_search_params" do
    before { controller.params = ActionController::Parameters.new(passed_params) }
    context "no sortable_search_params" do
      let(:passed_params) { {party: "stuff"} }
      it "returns an empty hash" do
        expect(sortable_search_params.to_unsafe_h).to eq({})
      end
    end
    context "query items" do
      let(:passed_params) { {query_items: %w[something iiiiii], search_email: "stttt"} }
      it "includes the query items" do
        expect(sortable_search_params.to_unsafe_h).to eq passed_params.as_json
      end
    end
    context "direction, sort" do
      let(:passed_params) { {direction: "asc", sort: "stolen", party: "long"} }
      let(:target) { {direction: "asc", sort: "stolen"} }
      it "returns target hash" do
        expect(sortable_search_params.to_unsafe_h).to eq(target.as_json)
      end
    end
    context "direction, sort, search param" do
      let(:time) { Time.current.to_i }
      let(:passed_params) { {direction: "asc", sort: "stolen", party: "long", search_stuff: "xxx", user_id: 21, organization_id: "xxx", start_time: time, end_time: time, period: "custom"} }
      let(:target) { {direction: "asc", sort: "stolen", search_stuff: "xxx", user_id: 21, organization_id: "xxx", start_time: time, end_time: time, period: "custom"} }
      it "returns target hash" do
        expect(sortable_search_params.to_unsafe_h).to eq(target.as_json)
      end
    end
    context "direction, sort, period: all " do
      let(:passed_params) { {direction: "asc", sort: "stolen", period: "all"} }
      let(:target) { {direction: "asc", sort: "stolen", period: "all"} }
      it "returns an empty hash" do
        expect(sortable_search_params?).to be_falsey
      end
    end
    context "direction, sort, period: week" do
      let(:passed_params) { {direction: "asc", sort: "stolen", period: "week"} }
      let(:target) { {direction: "asc", sort: "stolen", period: "week"} }
      it "returns an empty hash" do
        expect(sortable_search_params?).to be_truthy
      end
    end
  end
end
