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
    expect(link["data-ui--active-link-match-value"]).to eq "path"
    # :path compares the URL the browser is already on, so there's no route to compare
    expect(link.attributes).to_not have_key("data-ui--active-link-routes-value")
    expect(link.attributes).to_not have_key("data-ui--active-link-query-value")
  end

  context "with a class" do
    let(:options) { {class: "nav-link"} }

    it "renders it untouched -- the browser marks current with aria-current, not a class" do
      expect(link["class"]).to eq "nav-link"
    end
  end

  # The controller can't read the constant, so the copy in it drifts silently otherwise
  it "keeps the browser's ROUTE_MATCHES list in step with its own" do
    js = Rails.root.join("app/javascript/controllers/ui/active_link_controller.js").read
    expect(js[/const ROUTE_MATCHES = \[(.*?)\]/m, 1].scan(/'([a-z_]+)'/).flatten)
      .to eq described_class::ROUTE_MATCHES.map(&:to_s)
  end

  # Only :path can say "page" — the widened matches go active on a page the link doesn't
  # point at, so they say "true"
  describe "match" do
    context ":full_path" do
      let(:path) { "/o/example/bikes/new?parking_notification=true" }
      let(:options) { {match: :full_path} }

      it "compares in the browser, like :path" do
        expect(link["data-ui--active-link-match-value"]).to eq "full_path"
        expect(link.attributes).to_not have_key("data-ui--active-link-routes-value")
      end
    end

    context ":controller" do
      let(:path) { "/news" }
      let(:options) { {match: :controller} }

      it "carries the link's own route, which the page's is compared against" do
        expect(link["data-ui--active-link-match-value"]).to eq "controller"
        expect(link["data-ui--active-link-routes-value"]).to eq "news"
      end

      context "with matching_controllers" do
        let(:options) { {match: :controller, matching_controllers: ["organized/registration_sequence_pages"]} }

        it "adds them to the routes the browser compares" do
          expect(link["data-ui--active-link-routes-value"])
            .to eq "news organized/registration_sequence_pages"
        end
      end
    end

    context ":controller_action" do
      let(:path) { "/search/registrations?stolenness=all" }
      let(:options) { {match: :controller_action} }

      it "carries the route the params are dropped from" do
        expect(link["data-ui--active-link-match-value"]).to eq "controller_action"
        expect(link["data-ui--active-link-routes-value"]).to eq "search/registrations#index"
      end
    end

    context ":query" do
      let(:path) { "/o/example/impound_records" }
      let(:options) { {match: :query, query: {search_status: "resolved"}} }

      it "carries the params the browser compares the page's against" do
        expect(link["data-ui--active-link-match-value"]).to eq "query"
        expect(link["data-ui--active-link-query-value"]).to eq({search_status: ["resolved"]}.to_json)
        expect(link.attributes).to_not have_key("data-ui--active-link-routes-value")
      end

      # An entry that's the fallback a controller reaches for is in force with the param
      # absent, which is "" once the browser reads it off the URL
      context "with a nil among the values" do
        let(:options) { {match: :query, query: {search_status: ["current", nil]}} }

        it "renders it as the empty string" do
          expect(link["data-ui--active-link-query-value"])
            .to eq({search_status: ["current", ""]}.to_json)
        end
      end

      context "with a bare nil" do
        let(:options) { {match: :query, query: {search_deleted: nil}} }

        it "renders the one empty string, rather than no values at all" do
          expect(link["data-ui--active-link-query-value"]).to eq({search_deleted: [""]}.to_json)
        end
      end
    end

    context "with matching_controllers on a match that can't use them" do
      let(:options) { {match: :controller_action, matching_controllers: ["news"]} }

      it "raises rather than rendering entries the browser will never compare" do
        expect { component }.to raise_error(ArgumentError, /matching_controllers/)
      end
    end

    context "with query on a match that can't use it" do
      let(:options) { {match: :full_path, query: {search_status: "all"}} }

      it "raises rather than rendering params the browser will never compare" do
        expect { component }.to raise_error(ArgumentError, /query/)
      end
    end

    context "with match: :query and nothing to compare" do
      let(:options) { {match: :query} }

      it "raises rather than going active on every page" do
        expect { component }.to raise_error(ArgumentError, /query/)
      end
    end

    context "with a path that isn't a route" do
      let(:path) { "/not-a-route" }
      let(:options) { {match: :controller} }

      it "renders no route, so the link never goes active" do
        expect(link.attributes).to_not have_key("data-ui--active-link-routes-value")
      end
    end

    context "with an unknown match" do
      let(:options) { {match: :nonsense} }

      it "raises" do
        expect { component }.to raise_error(ArgumentError, /match/)
      end
    end
  end

  # Every menu renders its manifest's links through this, so the defaults are what a manifest
  # that leaves a key out gets
  describe "from_item" do
    let(:item) { {type: :link, label: "Help", path: "/help"} }
    let(:component) { render_inline(described_class.from_item(item, **options)) }

    it "fills in the match, and renders no class" do
      expect(link["href"]).to eq "/help"
      expect(link.text).to eq "Help"
      expect(link["data-ui--active-link-match-value"]).to eq "path"
      expect(link.attributes).to_not have_key("class")
      expect(link.attributes).to_not have_key("id")
    end

    context "with the keys a menu item can carry" do
      let(:item) do
        {type: :link, label: "Blog", path: "/news", match: :controller,
         matching_controllers: ["blogs"], id: "navBlog", data: {email: "party@bikeindex.org"}}
      end
      let(:options) { {link_class: "nav-link"} }

      it "passes each of them through" do
        expect(link["class"]).to eq "nav-link"
        expect(link["id"]).to eq "navBlog"
        expect(link["data-email"]).to eq "party@bikeindex.org"
        expect(link["data-ui--active-link-routes-value"]).to eq "news blogs"
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
