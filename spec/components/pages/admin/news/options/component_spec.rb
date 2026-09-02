# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pages::Admin::News::Options::Component, type: :component do
  let(:blog) { FactoryBot.create(:blog, info_kind:) }
  let(:info_kind) { false }
  let(:form_builder) do
    BikeIndexFormBuilder.new(:blog, blog, ActionView::Base.new(ActionView::LookupContext.new([]), {}, nil), {})
  end
  let(:component) { render_inline(described_class.new(form_builder:, blog:)) }
  let(:blog_only) { component.css("[data-admin--news-form-target='blogOnly']") }
  let(:info_only) { component.css("[data-admin--news-form-target='infoOnly']") }

  it "wires the info checkbox to both groups" do
    expect(component.css("[data-controller='admin--news-form']").count).to eq 1
    expect(component.css("[data-admin--news-form-target='infoKind']").count).to eq 1
    expect(blog_only.count).to eq 5
    expect(info_only.count).to eq 1
  end

  context "with a blog post" do
    it "shows the blog-only groups and hides the info-only one" do
      expect(blog_only.map { |el| el["class"] }).to all(satisfy { |c| !c.include?("tw:hidden") })
      expect(info_only.first["class"]).to match("tw:hidden")
    end
  end

  context "with an info post" do
    let(:info_kind) { true }

    it "hides the blog-only groups and shows the info-only one" do
      expect(blog_only.map { |el| el["class"] }).to all(match("tw:hidden"))
      expect(info_only.first["class"]).to_not match("tw:hidden")
    end
  end

  # step: 60 rejects a seeded value carrying seconds, and an unseeded field renders blank
  it "seeds the post date without seconds" do
    expect(component.css("#blog_post_date").first["value"]).to end_with(":00")
  end

  context "when the author has no personal page" do
    it "asks them to turn one on" do
      expect(component).to have_content("turn on your personal page")
    end
  end

  context "when the author has one" do
    let(:blog) { FactoryBot.create(:blog, user: FactoryBot.create(:user, show_bikes: true)) }

    it "says nothing" do
      expect(component).to_not have_content("turn on your personal page")
    end
  end

  context "with a listicle" do
    let(:blog) { FactoryBot.create(:blog, kind: :listicle) }

    # A listicle can't become an info post, so there's nothing to toggle with
    it "drops the info checkbox" do
      expect(component.css("[data-admin--news-form-target='infoKind']")).to be_empty
    end
  end
end
