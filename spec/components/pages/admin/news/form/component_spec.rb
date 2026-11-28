# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pages::Admin::News::Form::Component, type: :component do
  let(:blog) { FactoryBot.create(:blog, info_kind:, published:) }
  let(:info_kind) { false }
  let(:published) { false }
  let(:component) { render_inline(described_class.new(blog:)) }
  let(:blog_only) { component.css("[data-admin--news-form-target='blogOnly']") }
  let(:info_only) { component.css("[data-admin--news-form-target='infoOnly']") }

  it "renders the form, wired to the kind toggle" do
    expect(component.css("form#edit_blog_#{blog.id}[data-controller='admin--news-form']").count).to eq 1
    expect(component.css("[data-admin--news-form-target='infoKind']").count).to eq 1
    expect(component).to have_content("Draft")
    expect(blog_only.count).to eq 3
    expect(blog_only.map { it["class"] }).to all(satisfy { !it.include?("tw:hidden") })
    expect(info_only.first["class"]).to match("tw:hidden")
  end

  context "with a published info post" do
    let(:info_kind) { true }
    let(:published) { true }

    it "hides the blog-only groups and shows the info-only one" do
      expect(component).to have_content("Published")
      expect(blog_only.map { it["class"] }).to all(match("tw:hidden"))
      expect(info_only.first["class"]).to_not match("tw:hidden")
    end
  end

  # step: 60 rejects a seeded value carrying seconds, and an unseeded field renders blank
  it "seeds the post date without seconds" do
    expect(component.css("#blog_post_date").first["value"]).to end_with(":00")
  end
end
