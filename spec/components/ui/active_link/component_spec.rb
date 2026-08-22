# frozen_string_literal: true

require "rails_helper"

RSpec.describe UI::ActiveLink::Component, type: :component do
  let(:path) { "/help" }
  let(:options) { {} }
  let(:instance) { described_class.new(text: "Help", path:, **options) }
  let(:component) { render_inline(instance) }
  let(:link) { component.css("a").first }

  it "renders a link the browser resolves the state of" do
    expect(link["href"]).to eq path
    expect(link.text).to eq "Help"
    expect(link.attributes).to_not have_key("class")
    expect(link["data-controller"]).to eq "ui--active-link"
    expect(link["data-ui--active-link-match-paths-value"]).to eq "/help"
    # Naming no params is what leaves the page's own ignored
    expect(link.attributes).to_not have_key("data-ui--active-link-match-params-value")
  end

  context "with a class" do
    let(:options) { {class: "nav-link"} }

    it "renders it untouched -- the browser marks current with aria-current, not a class" do
      expect(link["class"]).to eq "nav-link"
    end
  end

  # The controller can't read the constant, so the copy in it drifts silently otherwise
  it "keeps the browser's BLANK in step with its own" do
    js = Rails.root.join("app/javascript/controllers/ui/active_link_controller.js").read
    expect(js[/const BLANK = '(\w+)'/, 1]).to eq described_class::BLANK.to_s
  end

  describe "match_paths" do
    context "with an href carrying an origin, params and an anchor" do
      let(:path) { "http://test.host/search/registrations?stolenness=all#results" }

      it "falls back to the page it points at, which is none of them" do
        expect(link["data-ui--active-link-match-paths-value"]).to eq "/search/registrations"
        expect(link["href"]).to eq path
      end
    end

    context "with patterns of its own" do
      let(:options) { {match_paths: ["/o/example/registration_sequences/**", "/bikes/*/edit"]} }

      it "carries them in place of the href's page" do
        expect(link["data-ui--active-link-match-paths-value"])
          .to eq "/o/example/registration_sequences/** /bikes/*/edit"
      end
    end

    context "with an origin in a pattern" do
      let(:options) { {match_paths: ["http://test.host/news/**"]} }

      it "drops it, since a pattern is compared against a pathname" do
        expect(link["data-ui--active-link-match-paths-value"]).to eq "/news/**"
      end
    end

    context "with a relative pattern" do
      let(:options) { {match_paths: ["news/**"]} }

      it "raises rather than comparing it against a path that always leads with /" do
        expect { component }.to raise_error(ArgumentError, %r{must start with /})
      end
    end

    # A route helper interpolated into a pattern carries the locale param
    context "with a pattern built around a helper's params" do
      let(:options) { {match_paths: ["/news?locale=nl/**"]} }

      it "drops them, leaving the rest of the pattern where it was written" do
        expect(link["data-ui--active-link-match-paths-value"]).to eq "/news/**"
      end
    end

    # The ambassador menu's Discuss row, which the browser rules out on the origin instead
    context "with an href that has no path of its own" do
      let(:path) { "https://discuss.bikeindex.org" }

      it "roots it, rather than falling back to nothing" do
        expect(link["data-ui--active-link-match-paths-value"]).to eq "/"
      end
    end

    context "with ** anywhere but the end" do
      let(:options) { {match_paths: ["/o/**/exports"]} }

      it "raises rather than matching only what a single * would" do
        expect { component }.to raise_error(ArgumentError, /\*\* only ends/)
      end
    end
  end

  describe "match_params" do
    let(:options) { {match_params: {search_status: "resolved"}} }

    it "carries the params the browser compares the page's against" do
      expect(link["data-ui--active-link-match-params-value"]).to eq({search_status: ["resolved"]}.to_json)
    end

    # An entry that's the fallback a controller reaches for is in force with the param absent
    context "with BLANK among the values" do
      let(:options) { {match_params: {search_status: ["current", described_class::BLANK]}} }

      it "carries it alongside them" do
        expect(link["data-ui--active-link-match-params-value"])
          .to eq({search_status: ["current", "blank"]}.to_json)
      end
    end

    context "with a value that isn't a string" do
      let(:options) { {match_params: {parking_notification: true}} }

      it "renders it as one, since that's what the browser reads off the URL" do
        expect(link["data-ui--active-link-match-params-value"])
          .to eq({parking_notification: ["true"]}.to_json)
      end
    end

    context "with nil in place of BLANK" do
      let(:options) { {match_params: {search_deleted: nil}} }

      it "raises rather than rendering a param with no values, which never matches" do
        expect { component }.to raise_error(ArgumentError, /blank/)
      end
    end

    context "with an empty list of values" do
      let(:options) { {match_params: {search_deleted: []}} }

      it "raises too" do
        expect { component }.to raise_error(ArgumentError, /blank/)
      end
    end
  end

  # Every menu renders its manifest's links through this, so the defaults are what a manifest
  # that leaves a key out gets
  describe "from_item" do
    let(:item) { {type: :link, label: "Help", path: "/help"} }
    let(:component) { render_inline(described_class.from_item(item, **options)) }

    it "falls back to the item's own path, and renders no class" do
      expect(link["href"]).to eq "/help"
      expect(link.text).to eq "Help"
      expect(link["data-ui--active-link-match-paths-value"]).to eq "/help"
      expect(link.attributes).to_not have_key("class")
      expect(link.attributes).to_not have_key("id")
    end

    context "with the keys a menu item can carry" do
      let(:item) do
        {type: :link, label: "Blog", path: "/news", match_paths: ["/news/**"],
         match_params: {sort: "recent"}, id: "navBlog",
         data: {email: "party@bikeindex.org"}}
      end
      let(:options) { {html_class: "nav-link"} }

      it "passes each of them through" do
        expect(link["class"]).to eq "nav-link"
        expect(link["id"]).to eq "navBlog"
        expect(link["data-email"]).to eq "party@bikeindex.org"
        expect(link["data-ui--active-link-match-paths-value"]).to eq "/news/**"
        expect(link["data-ui--active-link-match-params-value"]).to eq({sort: ["recent"]}.to_json)
      end
    end

    # A sidebar row's label sits inside a block with its icon, so it isn't the link's text
    context "with text: nil" do
      let(:options) { {text: nil} }
      let(:component) { render_inline(described_class.from_item(item, **options)) { "Block" } }

      it "takes the block's content over the item's label" do
        expect(link.text).to eq "Block"
      end
    end
  end

  context "with html_options and data" do
    let(:options) { {id: "footer-help", target: "_blank", data: {turbo: false, controller: "ui--dropdown"}} }

    it "passes them through to the anchor, and keeps the caller's controller" do
      expect(link["id"]).to eq "footer-help"
      expect(link["target"]).to eq "_blank"
      expect(link["data-turbo"]).to eq "false"
      expect(link["data-controller"]).to eq "ui--dropdown ui--active-link"
    end

    # aria-current is the browser's to set, so the server leaves the caller's aria alone
    context "including aria" do
      let(:options) { {aria: {label: "Help center"}} }

      it "keeps them, and marks no current" do
        expect(link["aria-label"]).to eq "Help center"
        expect(link.attributes).to_not have_key("aria-current")
      end
    end
  end

  context "with block content in place of text" do
    let(:instance) { described_class.new(path:) }
    let(:component) { render_inline(instance) { "<strong>Block</strong>".html_safe } }

    it "renders the block inside the link" do
      expect(link.css("strong").text).to eq "Block"
    end
  end

  context "with neither text nor block content" do
    let(:instance) { described_class.new(path:) }

    it "raises rather than labelling the link with its own URL" do
      expect { component }.to raise_error(ArgumentError, /text:/)
    end

    context "with a block that renders blank" do
      let(:component) { render_inline(instance) { "" } }

      it "raises too" do
        expect { component }.to raise_error(ArgumentError, /text:/)
      end
    end
  end

  # Menu labels interpolate organization names and user emails
  context "with markup in text" do
    let(:instance) { described_class.new(text: "<script>alert(1)</script>", path:) }

    it "escapes it" do
      expect(link.css("script")).to be_empty
      expect(link.text).to eq "<script>alert(1)</script>"
    end
  end
end
