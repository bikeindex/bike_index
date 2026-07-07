# frozen_string_literal: true

require "rails_helper"

RSpec.describe PageBlock::ReviewAppBanner::Component, type: :component do
  it "doesn't render when review_app is blank" do
    expect(described_class.new(review_app: nil).render?).to be_falsey
    expect(described_class.new(review_app: "").render?).to be_falsey
  end

  context "when review_app is present" do
    let(:component) { render_inline(described_class.new(review_app: "1", pr_number:, pr_title:)) }
    let(:pr_number) { nil }
    let(:pr_title) { nil }

    it "renders the label and disclaimer" do
      expect(component.text).to include("Review app")
      expect(component.text).to include("data is ephemeral")
    end

    it "doesn't render the superadmin button when there is no superadmin" do
      expect(component.css("form[action='/session/sign_in_with_magic_link']")).to be_empty
    end

    context "with a superadmin" do
      let!(:superadmin) { FactoryBot.create(:superuser) }

      it "renders a button posting the superadmin's magic link token" do
        form = component.css("form[action='/session/sign_in_with_magic_link']").first
        expect(form).to be_present
        expect(form.css("button").text).to eq("sign in as superadmin")
        expect(form.css("input[name='token']").first[:value]).to eq superadmin.reload.magic_link_token
      end

      # The banner renders on pages served under set_reading_role, so refreshing
      # the (persisted) token must not raise ActiveRecord::ReadOnlyError
      it "generates the token under the reading database role" do
        input = ActiveRecord::Base.connected_to(role: :reading) do
          render_inline(described_class.new(review_app: "1"))
            .css("form[action='/session/sign_in_with_magic_link'] input[name='token']").first
        end
        expect(input[:value]).to eq superadmin.reload.magic_link_token
      end
    end

    it "links to the letter_opener outbox with a tooltip" do
      outbox = component.css("a[href='/letter_opener']").first
      expect(outbox).to be_present
      expect(outbox.text).to include("email outbox")
      expect(component.css("[role='tooltip']").text).to include("View the email sent by this review app")
    end

    it "omits the PR link when no pr_number is given" do
      expect(component.css("a[href^='https://github.com']")).to be_empty
    end

    context "with a pr_number" do
      let(:pr_number) { 1234 }

      it "links to the PR on github.com/bikeindex/bike_index" do
        link = component.css("a[href^='https://github.com']").first
        expect(link[:href]).to eq("https://github.com/bikeindex/bike_index/pull/1234")
        expect(link.text).to include("PR #1234")
      end

      context "with a pr_title" do
        let(:pr_title) { "Add Promoted section" }

        it "uses the title as the PR link text" do
          link = component.css("a[href^='https://github.com']").first
          expect(link[:href]).to eq("https://github.com/bikeindex/bike_index/pull/1234")
          expect(link.text.strip).to eq("Add Promoted section")
        end
      end
    end
  end
end
