# frozen_string_literal: true

require "rails_helper"

RSpec.describe Admin::UserIcon::Component, type: :component do
  def render_component(user:, full_text: false)
    render_inline(described_class.new(user:, full_text:))
  end

  describe "with no user" do
    it "renders nothing" do
      result = render_component(user: nil)
      expect(result.to_html).to be_blank
    end

    it "renders nothing for new user" do
      result = render_component(user: User.new)
      expect(result.to_html).to be_blank
    end
  end

  describe "donor" do
    let(:payment) { FactoryBot.create(:payment, kind: "donation") }
    let(:user) { payment.user }

    it "renders donor icon" do
      expect(user.donor?).to be_truthy
      result = render_component(user:)
      expect(result).to have_text("D")
      expect(result).to have_css("[title='Donor']", text: "D")

      result_full = render_component(user:, full_text: true)
      expect(result_full).to have_css("[title='Donor']", text: "D")
      expect(result_full).to have_text(/D\s*onor/)
    end

    context "with theft alert" do
      let!(:theft_alert) { FactoryBot.create(:theft_alert_paid, user:) }

      it "renders both donor and theft alert icons" do
        expect(user.donor?).to be_truthy
        expect(user.theft_alert_purchaser?).to be_truthy
        result = render_component(user:)
        expect(result).to have_css("[title='Donor']", text: "D")
        expect(result).to have_css("[title='Promoted alert purchaser']", text: "P")

        # If superuser, don't show other stuff
        user.superuser = true
        result_superuser = render_component(user:)
        expect(result_superuser).to have_css("[title='Superuser']", text: "S")
      end
    end
  end

  describe "member" do
    let(:membership) { FactoryBot.create(:membership, start_at: 1.year.ago, end_at:) }
    let(:end_at) { Time.current + 1.day }
    let(:user) { membership.user }

    it "renders member icon" do
      expect(membership.reload.status).to eq "active"
      expect(user.donor?).to be_falsey
      result = render_component(user:)
      expect(result).to have_css("[title='Member']")

      component_text = whitespace_normalized_body_text(result.to_html)
      expect(component_text).to eq("M")
    end

    it "renders full text" do
      result = render_component(user:, full_text: true)
      component_text = whitespace_normalized_body_text(result.to_html)
      expect(component_text).to eq("M Member")
    end

    context "membership ended" do
      let(:end_at) { Time.current - 1.hour }

      it "renders nothing" do
        expect(membership.reload.status).to eq "ended"
        result = render_component(user:)
        expect(result.to_html).to be_blank
      end
    end
  end

  describe "recovery" do
    let(:bike) { FactoryBot.create(:bike, :with_ownership_claimed) }
    let!(:stolen_record_recovered) { FactoryBot.create(:stolen_record_recovered, bike:) }
    let(:user) { bike.user }

    it "renders recovery icon" do
      expect(user.reload).to be_present
      result = render_component(user:)
      component_text = whitespace_normalized_body_text(result.to_html)
      expect(component_text).to eq("R")
    end
  end

  describe "organization" do
    let(:organization) { FactoryBot.create(:organization, kind: "bike_shop") }
    let(:user) { FactoryBot.create(:organization_user, organization:) }

    it "renders org icon for unpaid org" do
      expect(user.paid_org?).to be_falsey
      result = render_component(user:)
      expect(result).to have_css("[title='organization member - Bike Shop']")
      expect(result).to have_text("O-BS")
    end

    context "paid org" do
      let(:organization) { FactoryBot.create(:organization, :organization_features, kind: "law_enforcement") }

      it "renders paid org icon" do
        expect(user.paid_org?).to be_truthy
        allow_any_instance_of(Organization).to receive(:paid_money?).and_return(true)
        result = render_component(user:)
        expect(result).to have_css("[title='Paid organization member - Law Enforcement']")

        component_text = whitespace_normalized_body_text(result.to_html)
        expect(component_text).to eq("$O-P")

        result_full = render_component(user:, full_text: true)
        component_text = whitespace_normalized_body_text(result_full.to_html)
        expect(component_text).to eq("$O-P Paid organization member - Law Enforcement")
      end
    end
  end

  describe "banned" do
    let(:user) { FactoryBot.create(:user, banned: true) }
    it "shows banned" do
      result = render_component(user:)
      expect(result).to have_text("B")
      expect(result).to have_css("[title='Banned']")

      result_full = render_component(user:, full_text: true)
      component_text = whitespace_normalized_body_text(result_full.to_html)
      expect(component_text).to eq("B Banned")
    end

    context "with user_ban" do
      let!(:user_ban) { UserBan.create(user:, reason: :known_criminal) }

      it "shows ban reason" do
        user.reload
        result = render_component(user:)
        expect(result).to have_text("B")
        expect(result).to have_css("[title='Banned: Known criminal']")

        result_full = render_component(user:, full_text: true)
        component_text = whitespace_normalized_body_text(result_full.to_html)
        expect(component_text).to eq("B Banned: Known criminal")
      end
    end
  end

  describe "email_ban" do
    let(:email_ban) { FactoryBot.create(:email_ban) }
    let(:user) { email_ban.user }
    it "shows email banned" do
      result = render_component(user:)
      expect(result).to have_text("EB")
      expect(result).to have_css("[title='Email Banned: domain']")

      result_full = render_component(user:, full_text: true)
      component_text = whitespace_normalized_body_text(result_full.to_html)
      expect(component_text).to eq("EB Email Banned: domain")
    end
  end
end
