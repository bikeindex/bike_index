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
  end

  context "with html_class" do
    let(:options) { {html_class: "nav-link"} }

    it "renders the class on its own, for the controller to append to" do
      expect(link["class"]).to eq "nav-link"
    end
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
        expect(link["data-ui--active-link-routes-value"]).to eq "news#index"
      end

      context "with matching_controllers" do
        let(:options) { {match: :controller, matching_controllers: ["organized/registration_sequence_pages"]} }

        it "adds them to the routes the browser compares" do
          expect(link["data-ui--active-link-routes-value"])
            .to eq "news#index organized/registration_sequence_pages"
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

  context "with a class in html_options" do
    let(:options) { {class: "nav-link"} }

    it "raises, since html_class is the way in" do
      expect { component }.to raise_error(ArgumentError, /html_class/)
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
