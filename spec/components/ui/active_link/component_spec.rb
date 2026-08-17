# frozen_string_literal: true

require "rails_helper"

RSpec.describe UI::ActiveLink::Component, type: :component do
  let(:path) { "/help" }
  let(:request_url) { "/" }
  let(:options) { {} }
  let(:instance) { described_class.new(text: "Help", path:, **options) }
  let(:component) { with_request_url(request_url) { render_inline(instance) } }
  let(:link) { component.css("a").first }

  it "renders a plain link when it isn't the current page" do
    expect(link["href"]).to eq path
    expect(link.text).to eq "Help"
    expect(link.attributes).to_not have_key("class")
  end

  context "on the linked page" do
    let(:request_url) { path }

    it "marks the link active" do
      expect(link["class"]).to eq "active"
    end
  end

  context "with html_class" do
    let(:options) { {html_class: "nav-link"} }

    it "renders the class on its own" do
      expect(link["class"]).to eq "nav-link"
    end

    context "on the linked page" do
      let(:request_url) { path }

      it "appends active" do
        expect(link["class"]).to eq "nav-link active"
      end
    end
  end

  describe "match" do
    let(:path) { "/bikes/new" }
    let(:request_url) { "/bikes/12" }

    it "defaults to :path, so another page of the controller isn't active" do
      expect(link["class"]).to be_blank
    end

    context ":controller" do
      let(:options) { {match: :controller} }

      it "is active on another page of the same controller" do
        expect(link["class"]).to eq "active"
      end

      context "on a page of a different controller" do
        let(:request_url) { "/help" }

        it "isn't active" do
          expect(link["class"]).to be_blank
        end
      end
    end

    context ":controller_action" do
      let(:options) { {match: :controller_action} }

      it "isn't active on a different action of the same controller" do
        expect(link["class"]).to be_blank
      end

      # What a link carrying query params needs — the URL won't compare equal
      context "on the same action, reached with different params" do
        let(:path) { "/search/registrations?stolenness=all" }
        let(:request_url) { "/search/registrations?query=trek" }

        it "is active" do
          expect(link["class"]).to eq "active"
        end
      end

      context "on a different controller's index" do
        let(:path) { "/search/registrations?stolenness=all" }
        let(:request_url) { "/search/marketplace" }

        it "isn't active" do
          expect(link["class"]).to be_blank
        end
      end
    end
  end

  context "with an unknown match" do
    let(:options) { {match: :nonsense} }

    it "raises" do
      expect { component }.to raise_error(ArgumentError, /match/)
    end
  end

  describe "active" do
    context "forced true off the linked page" do
      let(:options) { {active: true} }

      it "skips the current page check" do
        expect(link["class"]).to eq "active"
      end
    end

    context "forced false on the linked page" do
      let(:request_url) { path }
      let(:options) { {active: false} }

      it "skips the current page check" do
        expect(link.attributes).to_not have_key("class")
      end
    end
  end

  context "with a class in html_options" do
    let(:options) { {class: "nav-link"} }

    it "raises, since the component builds its own" do
      expect { component }.to raise_error(ArgumentError, /html_class/)
    end
  end

  context "with html_options" do
    let(:options) { {id: "footer-help", target: "_blank"} }

    it "passes them through to the anchor" do
      expect(link["id"]).to eq "footer-help"
      expect(link["target"]).to eq "_blank"
    end
  end

  context "with block content in place of text" do
    let(:instance) { described_class.new(path:) }
    let(:component) do
      with_request_url(request_url) { render_inline(instance) { "<strong>Block</strong>".html_safe } }
    end

    it "renders the block inside the link" do
      expect(link.css("strong").text).to eq "Block"
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
