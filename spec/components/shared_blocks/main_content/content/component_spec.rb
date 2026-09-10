# frozen_string_literal: true

require "rails_helper"

RSpec.describe SharedBlocks::MainContent::Content::Component, type: :component do
  include Rails.application.routes.url_helpers

  let(:options) do
    {blog: nil, related_blogs: nil, source: nil, current_user: nil, controller_name:, action_name:}
  end
  let(:controller_name) { "info" }
  let(:action_name) { "about" }
  let(:component) { render_inline(described_class.new(**options)) { "<p>the page</p>".html_safe } }

  it "renders the page in the content column, with the related menu" do
    expect(component.css(".primary-content-block").to_html).to match("<p>the page</p>")
    expect(component.text).to match "Related"
    expect(component.text).to match "Other pages"
  end

  context "info page" do
    let(:action_name) { "where" }

    it "includes the help and where links, and the organization sign up where earns it" do
      expect(component.text).to match "Where"
      expect(component.text).to match "Sign up your organization"
      expect(component.css("a[href$='#{help_path}']").count).to eq 1
    end
  end

  context "news page" do
    let(:controller_name) { "news" }
    let(:action_name) { "index" }

    it "swaps the info links for the news links" do
      expect(component.text).to_not match "Where"
      # The related section's link replaces the one "Other pages" carries elsewhere
      link = component.css("a[href='#{news_index_path}']")
      expect(link.count).to eq 1
      expect(link.first["data-ui--active-link-match-paths-value"]).to eq news_index_path
      expect(component.text).to match "Bike Index Store"
    end
  end

  context "with a blog" do
    let(:controller_name) { "news" }
    let(:action_name) { "show" }
    let(:blog) { FactoryBot.create(:blog, title: "Some cool story") }
    let(:options) { super().merge(blog:, related_blogs: [blog]) }

    it "renders the related blogs, and no edit link" do
      expect(component.text).to match "Some cool story"
      expect(component.css("a[href='#{edit_admin_news_path(blog)}']").count).to eq 0
    end

    context "superuser" do
      let(:options) { super().merge(current_user: FactoryBot.create(:superuser)) }

      it "renders the edit link" do
        expect(component.css("a[href='#{edit_admin_news_path(blog)}']").count).to eq 1
      end
    end

    context "why donate" do
      let(:blog) { Blog.new(title_slug: Blog.why_donate_slug) }
      let(:options) { super().merge(related_blogs: nil) }

      it "renders the donation ask rather than the menu" do
        expect(component.text).to match "Make a difference in bike theft"
        expect(component.text).to_not match "Other pages"
        expect(component.css("a[href='#{donate_path(source: "why-donate")}']").count).to eq 1
      end

      context "with an incoming source" do
        let(:options) { super().merge(source: "newsletter") }

        it "carries it through to the donate links" do
          expect(component.css("a[href='#{donate_path(source: "newsletter")}']").count).to eq 1
          expect(component.css("a[href='#{donate_path(initial_amount: 50, source: "newsletter")}']").count).to eq 1
        end
      end
    end
  end
end
