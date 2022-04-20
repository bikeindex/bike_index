require "rails_helper"

RSpec.describe MailerHelper, type: :helper do
  describe "render_donation?" do
    let(:organization) { Organization.new(kind: "bike_shop") }
    it "is truthy" do
      expect(render_donation?).to be_truthy
      expect(render_donation?(organization)).to be_truthy
    end
    context "organization with invoice" do
      let(:organization) { FactoryBot.create(:organization_with_organization_features) }
      it "is falsey" do
        expect(organization.reload.paid?).to be_truthy
        expect(organization.paid_money?).to be_falsey
        expect(render_donation?(organization)).to be_truthy
      end
    end
    context "organization paid_money" do
      let(:organization) { FactoryBot.create(:organization_with_organization_features) }
      let!(:invoice2) { FactoryBot.create(:invoice_with_payment, organization: organization) }
      it "is falsey" do
        expect(organization.reload.paid?).to be_truthy
        expect(organization.paid_money?).to be_truthy
        expect(render_donation?(organization)).to be_falsey
      end
    end
  end

  describe "render_supporters?" do
    let(:organization) { Organization.new(kind: "bike_advocacy") }
    it "is truthy" do
      organization.kind = "bike_advocacy" # IDK why this fails if it isn't assigned here, maybe a default issue?
      expect(render_supporters?).to be_truthy
      expect(render_supporters?(organization)).to be_truthy
    end
    let(:organization) { Organization.new(kind: "bike_shop") }
    it "is truthy" do
      expect(render_supporters?(organization)).to be_falsey
    end
    context "organization with invoice" do
      let(:organization) { FactoryBot.create(:organization_with_organization_features) }
      it "is falsey" do
        expect(organization.reload.paid?).to be_truthy
        expect(render_supporters?(organization)).to be_truthy
      end
    end
    context "organization paid_money" do
      let(:organization) { FactoryBot.create(:organization_with_organization_features) }
      let!(:invoice2) { FactoryBot.create(:invoice_with_payment, organization: organization) }
      it "is falsey" do
        expect(organization.reload.paid?).to be_truthy
        expect(organization.paid_money?).to be_truthy
        expect(render_supporters?(organization)).to be_falsey
      end
    end
  end
end
