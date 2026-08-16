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
    expect(link["class"]).to be_blank
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

  describe "match_controller" do
    let(:path) { "/bikes/new" }
    let(:request_url) { "/bikes/12" }

    it "isn't active on another page of the same controller" do
      expect(link["class"]).to be_blank
    end

    context "with match_controller" do
      let(:options) { {match_controller: true} }

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
