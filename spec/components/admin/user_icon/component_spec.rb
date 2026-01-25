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
      expect(result).to have_css(".donor-icon", text: "D")
      expect(result).to have_css("[title='Donor']")
    end

    it "renders full text" do
      result = render_component(user:, full_text: true)
      expect(result).to have_css(".donor-icon", text: "D")
      expect(result).to have_text("onor")
    end

    context "with theft alert" do
      let!(:theft_alert) { FactoryBot.create(:theft_alert_paid, user:) }

      it "renders both donor and theft alert icons" do
        expect(user.donor?).to be_truthy
        expect(user.theft_alert_purchaser?).to be_truthy
        result = render_component(user:)
        expect(result).to have_css(".donor-icon", text: "D")
        expect(result).to have_css(".theft-alert-icon", text: "P")
      end

      it "renders only superuser when superuser" do
        user.superuser = true
        result = render_component(user:)
        expect(result).to have_css(".superuser-icon", text: "S")
        expect(result).not_to have_css(".donor-icon")
        expect(result).not_to have_css(".theft-alert-icon")
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
      expect(result).to have_css(".donor-icon", text: "M")
      expect(result).to have_css("[title='Member']")
    end

    it "renders full text" do
      result = render_component(user:, full_text: true)
      expect(result).to have_text("ember")
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
      expect(result).to have_css(".recovery-icon", text: "R")
    end
  end

  describe "organization" do
    let(:organization) { FactoryBot.create(:organization, kind: "bike_shop") }
    let(:user) { FactoryBot.create(:organization_user, organization:) }

    it "renders org icon for unpaid org" do
      expect(user.paid_org?).to be_falsey
      result = render_component(user:)
      expect(result).to have_css(".org-member-icon")
      expect(result).to have_css("[title='organization member - Bike Shop']")
    end

    context "paid org" do
      let(:organization) { FactoryBot.create(:organization, :organization_features, kind: "law_enforcement") }

      it "renders paid org icon" do
        expect(user.paid_org?).to be_truthy
        result = render_component(user:)
        expect(result).to have_css(".org-member-icon", text: "$O P")
        expect(result).to have_css("[title='Paid organization member - Law Enforcement']")
      end

      it "renders full text" do
        result = render_component(user:, full_text: true)
        expect(result).to have_text("Paid organization member - Law Enforcement")
      end
    end
  end
end
