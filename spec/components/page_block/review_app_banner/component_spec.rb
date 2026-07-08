# frozen_string_literal: true

require "rails_helper"

RSpec.describe PageBlock::ReviewAppBanner::Component, type: :component do
  it "doesn't render when review_app is blank" do
    expect(described_class.new(review_app: nil).render?).to be_falsey
    expect(described_class.new(review_app: "").render?).to be_falsey
  end

  context "when review_app is present" do
    let(:component) { render_inline(described_class.new(review_app: "1", pr_number:, pr_title:, commit:, current_user:, return_to:)) }
    let(:pr_number) { nil }
    let(:pr_title) { nil }
    let(:commit) { nil }
    let(:current_user) { nil }
    let(:return_to) { nil }

    it "renders the staging label and disclaimer" do
      # No pr_number is the persistent staging deploy, not a per-PR review app
      expect(component.text).to include("Staging")
      expect(component.text).not_to include("Review app")
      expect(component.text).to include("data is ephemeral")
    end

    it "hides the label and disclaimer on small screens" do
      # tw:hidden tw:sm:inline => display:none below the sm breakpoint
      label = component.css("span.tw\\:hidden", text: "Staging").first
      disclaimer = component.css("span.tw\\:hidden", text: "data is ephemeral").first
      expect(label).to be_present
      expect(disclaimer).to be_present
      # The outbox link stays visible, so it's not inside a hidden span
      expect(component.css("span.tw\\:hidden a[href='/letter_opener']")).to be_empty
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
        expect(form.css("input[name='return_to']")).to be_empty
      end

      context "with a return_to" do
        let(:return_to) { "/bikes/12" }

        it "posts the return_to so sign-in redirects back to the current page" do
          form = component.css("form[action='/session/sign_in_with_magic_link']").first
          expect(form.css("input[name='return_to']").first[:value]).to eq "/bikes/12"
        end
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

      context "when signed in as the superadmin" do
        let(:current_user) { superadmin }

        it "shows a signed-in label instead of the button" do
          expect(component.css("form[action='/session/sign_in_with_magic_link']")).to be_empty
          expect(component.text).to include("signed in as superadmin")
        end
      end

      context "when signed in as another user" do
        let(:current_user) { FactoryBot.create(:user_confirmed) }

        it "still renders the sign in button" do
          expect(component.css("form[action='/session/sign_in_with_magic_link']")).to be_present
          expect(component.text).not_to include("signed in as superadmin")
        end
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

    it "omits the commit tooltip when no commit is given" do
      expect(component.text).not_to include("current commit")
    end

    context "with a commit" do
      let(:commit) { "a1b2c3d" }

      it "renders a tooltip with the current commit after the label" do
        expect(component.css("[role='tooltip']").text).to include("current commit: a1b2c3d")
        expect(component.text).to include("a1b2c3d")
      end
    end

    context "with a pr_number" do
      let(:pr_number) { 1234 }

      it "links to the PR on github.com/bikeindex/bike_index" do
        link = component.css("a[href^='https://github.com']").first
        expect(link[:href]).to eq("https://github.com/bikeindex/bike_index/pull/1234")
        expect(link.text).to include("PR #1234")
      end

      it "shows the review app label instead of the staging label" do
        expect(component.text).to include("Review app")
        expect(component.text).not_to include("Staging")
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
