# frozen_string_literal: true

require "rails_helper"

RSpec.describe SharedBlocks::ReviewAppBanner::Component, type: :component do
  it "doesn't render when review_app is blank" do
    expect(described_class.new(review_app: nil).render?).to be_falsey
    expect(described_class.new(review_app: "").render?).to be_falsey
    expect(described_class.new(review_app: nil).lookbook_navbar_title).to be_nil
  end

  describe ".from_env" do
    it "doesn't render without REVIEW_APP outside of development" do
      expect(described_class.from_env.render?).to be_falsey
    end

    context "with the review app env" do
      let(:review_app_env) do
        {"REVIEW_APP" => "1", "REVIEW_APP_PR_NUMBER" => "1234", "REVIEW_APP_PR_TITLE" => "Add Promoted section",
         "REVIEW_APP_COMMIT" => "a1b2c3d"}
      end

      before { stub_const("ENV", ENV.to_hash.merge(review_app_env)) }

      it "reads the deploy's PR from the env" do
        expect(described_class.from_env.lookbook_navbar_title).to eq "Add Promoted section"
      end

      it "doesn't render with NO_REVIEW_TOPBAR" do
        stub_const("ENV", ENV.to_hash.merge(review_app_env, "NO_REVIEW_TOPBAR" => "true"))
        expect(described_class.from_env.render?).to be_falsey
        expect(described_class.from_env.lookbook_navbar_title).to be_nil
      end
    end
  end

  it "renders a purple development banner for the local dev server" do
    banner = described_class.new(review_app: "development")
    component = render_inline(banner)
    # The label is on-page only — without a PR the Lookbook navbar gets no suffix
    expect(banner.lookbook_navbar_title).to be_nil
    expect(component.text).to include("Development")
    expect(component.text).not_to include("Sandbox")
    expect(component.css("a[href='/letter_opener']")).to be_present
    # Purple accent (matching the dev favicon) instead of the review-app green
    expect(component.to_html).to include("tw:bg-[#ff40ff]")
    expect(component.to_html).not_to include("tw:bg-[#40ff40]")
    # The local database persists, so the ephemeral-data disclaimer doesn't apply
    expect(component.text).not_to include("data is ephemeral")
  end

  it "offers the superadmin sign-in button in development" do
    FactoryBot.create(:superuser)
    component = render_inline(described_class.new(review_app: "development"))
    expect(component.css("form[action='/session/sign_in_with_magic_link'] button").text).to eq("sign in as superadmin")
  end

  context "when review_app is present" do
    let(:banner) { described_class.new(review_app: "1", pr_number:, pr_title:, commit:, current_user:, return_to:) }
    let(:component) { render_inline(banner) }
    let(:pr_number) { nil }
    let(:pr_title) { nil }
    let(:commit) { nil }
    let(:current_user) { nil }
    let(:return_to) { nil }

    it "renders the sandbox label and disclaimer" do
      # No pr_number is the persistent sandbox deploy, not a per-PR review app
      expect(banner.lookbook_navbar_title).to be_nil
      expect(component.text).to include("Sandbox")
      expect(component.text).not_to include("Review app")
      expect(component.text).to include("data is ephemeral")
    end

    it "keeps the Sandbox label visible on small screens but hides the disclaimer" do
      # tw:hidden tw:sm:inline => display:none below the sm breakpoint. Sandbox has
      # no PR title, so the label itself carries the context on small screens.
      label = component.css("span").find { |span| span.text.strip == "Sandbox" }
      disclaimer = component.css("span").find { |span| span.text.include?("data is ephemeral") }
      expect(label[:class].to_s).not_to include("tw:hidden")
      expect(disclaimer[:class].to_s).to include("tw:hidden")
    end

    it "says signing in isn't possible when there is no superadmin" do
      expect(component.css("form[action='/session/sign_in_with_magic_link']")).to be_empty
      expect(component.text).to include("no superuser (can't signin)")
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

      it "renders a '?' tooltip whose popup links to the commit on github" do
        # visible trigger is "?" (like the email-outbox tooltip), not the raw SHA
        button = component.css("button[aria-label='current commit: a1b2c3d']").first
        expect(button.text.strip).to eq("?")
        tooltip = component.css("[role='tooltip']")
        expect(tooltip.text).to include("current commit:")
        link = tooltip.css("a").first
        expect(link[:href]).to eq("https://github.com/bikeindex/bike_index/commit/a1b2c3d")
        expect(link.text.strip).to eq("a1b2c3d")
      end

      it "shows the commit tooltip on small screens (not inside a hidden span)" do
        expect(component.css("span.tw\\:hidden button[aria-label='current commit: a1b2c3d']")).to be_empty
      end
    end

    context "with a pr_number" do
      let(:pr_number) { 1234 }

      it "links to the PR on github.com/bikeindex/bike_index" do
        link = component.css("a[href^='https://github.com']").first
        expect(link[:href]).to eq("https://github.com/bikeindex/bike_index/pull/1234")
        expect(link.text).to include("PR #1234")
      end

      it "shows the review app label instead of the sandbox label, hidden on small screens" do
        # The banner keeps the label; the Lookbook navbar shows only the PR
        expect(banner.lookbook_navbar_title).to eq "PR #1234"
        expect(component.text).to include("Review app")
        expect(component.text).not_to include("Sandbox")
        # The PR title carries the context on small screens, so the label hides
        label = component.css("span").find { |span| span.text.strip == "Review app" }
        expect(label[:class].to_s).to include("tw:hidden")
      end

      context "with a pr_title" do
        let(:pr_title) { "Add Promoted section" }

        it "uses the title as the PR link text" do
          expect(banner.lookbook_navbar_title).to eq "Add Promoted section"
          link = component.css("a[href^='https://github.com']").first
          expect(link[:href]).to eq("https://github.com/bikeindex/bike_index/pull/1234")
          expect(link.text.strip).to eq("Add Promoted section")
        end
      end
    end
  end
end
