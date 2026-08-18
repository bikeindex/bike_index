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
    expect(link.attributes).to_not have_key("data-ui--active-link-route-value")
  end

  context "with html_class" do
    let(:options) { {html_class: "nav-link"} }

    it "renders the class on its own, for the controller to append to" do
      expect(link["class"]).to eq "nav-link"
    end
  end

  describe "match" do
    context ":controller" do
      let(:path) { "/news" }
      let(:options) { {match: :controller} }

      it "carries the link's own route, which the page's is compared against" do
        expect(link["data-ui--active-link-match-value"]).to eq "controller"
        expect(link["data-ui--active-link-route-value"]).to eq "news#index"
      end
    end

    context ":controller_action" do
      let(:path) { "/search/registrations?stolenness=all" }
      let(:options) { {match: :controller_action} }

      it "carries the route the params are dropped from" do
        expect(link["data-ui--active-link-match-value"]).to eq "controller_action"
        expect(link["data-ui--active-link-route-value"]).to eq "search/registrations#index"
      end
    end

    context "with a path that isn't a route" do
      let(:path) { "/not-a-route" }
      let(:options) { {match: :controller} }

      it "renders no route, so the link never goes active" do
        expect(link.attributes).to_not have_key("data-ui--active-link-route-value")
      end
    end

    context "with an unknown match" do
      let(:options) { {match: :nonsense} }

      it "raises" do
        expect { component }.to raise_error(ArgumentError, /match/)
      end
    end
  end

  describe "active" do
    context "true" do
      let(:options) { {active: true, html_class: "nav-link"} }

      it "renders the class, and no controller to resolve what it already knows" do
        expect(link["class"]).to eq "nav-link active"
        expect(link.attributes).to_not have_key("data-controller")
      end
    end

    context "false" do
      let(:options) { {active: false} }

      it "renders neither" do
        expect(link.attributes).to_not have_key("class")
        expect(link.attributes).to_not have_key("data-controller")
      end
    end
  end

  # A menu picking out its current entry asks the class method, rather than rendering a link
  # to find out — Admin::Navbar's picker does
  describe ".active?" do
    let(:match) { :path }
    let(:request_url) { "/" }
    let(:active) do
      with_request_url(request_url) do
        described_class.active?(path:, match:, view: vc_test_controller.view_context)
      end
    end

    it "is false off the page the link points at" do
      expect(active).to be false
    end

    context "on the linked page" do
      let(:request_url) { path }

      it "is true" do
        expect(active).to be true
      end
    end

    context "with match: :controller" do
      let(:match) { :controller }
      let(:path) { "/bikes/new" }
      let(:request_url) { "/bikes/12" }

      it "is true on another page of the same controller" do
        expect(active).to be true
      end

      context "on a page of a different controller" do
        let(:request_url) { "/help" }

        it "is false" do
          expect(active).to be false
        end
      end
    end

    context "with match: :controller_action" do
      let(:match) { :controller_action }
      let(:path) { "/search/registrations?stolenness=all" }
      let(:request_url) { "/search/registrations?query=trek" }

      # What a link carrying query params needs — the URL won't compare equal
      it "is true on the same action, reached with different params" do
        expect(active).to be true
      end

      context "on a different controller's index" do
        let(:request_url) { "/search/marketplace" }

        it "is false" do
          expect(active).to be false
        end
      end

      # A failed update re-renders the form, so the page is a PATCH dispatching bikes#update.
      # Recognizing that URL as a GET compares bikes#show, and the link goes active on a page
      # it doesn't point at
      context "on a page rendered by a non-GET request" do
        let(:path) { "/bikes/12" }
        let(:request_url) { path }

        it "compares the action the request dispatched, not the GET route's" do
          expect(active).to be true

          on_patch = with_request_url(request_url, method: "PATCH") do
            described_class.active?(path:, match:, view: vc_test_controller.view_context)
          end
          expect(on_patch).to be false
        end
      end
    end
  end

  context "with a class in html_options" do
    let(:options) { {class: "nav-link"} }

    it "raises, since the component builds its own" do
      expect { component }.to raise_error(ArgumentError, /html_class/)
    end
  end

  context "with html_options and data" do
    let(:options) { {id: "footer-help", target: "_blank", data: {turbo: false}} }

    it "passes them through to the anchor, alongside the controller" do
      expect(link["id"]).to eq "footer-help"
      expect(link["target"]).to eq "_blank"
      expect(link["data-turbo"]).to eq "false"
      expect(link["data-controller"]).to eq "ui--active-link"
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
