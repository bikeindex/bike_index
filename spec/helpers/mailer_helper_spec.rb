require "rails_helper"

RSpec.describe MailerHelper, type: :helper do
  # Organized::EmailsController's previews render the email layout with no message
  describe "render_donation?" do
    it "is truthy" do
      expect(helper.render_donation?).to be_truthy
    end

    context "paid organization" do
      before { assign(:organization, FactoryBot.create(:invoice_with_payment).organization) }

      it "is falsey" do
        expect(helper.render_donation?).to be_falsey
      end
    end
  end

  describe "render_supporters?" do
    let(:organization) { Organization.new(kind: "bike_advocacy") }
    it "is falsey" do
      expect(render_supporters?).to be_falsey
      expect(render_supporters?(organization)).to be_falsey
    end
    context "bike_shop organization" do
      let(:organization) { Organization.new(kind: "bike_shop") }
      it "is falsey" do
        expect(render_supporters?(organization)).to be_falsey
      end
    end
    context "organization with invoice" do
      let(:organization) { FactoryBot.create(:organization_with_organization_features) }
      it "is falsey" do
        expect(organization.reload.is_invoiced?).to be_truthy
        expect(render_supporters?(organization)).to be_falsey
      end
    end
    context "organization paid_money" do
      let(:organization) { FactoryBot.create(:organization_with_organization_features) }
      let!(:invoice2) { FactoryBot.create(:invoice_with_payment, organization: organization) }
      it "is falsey" do
        expect(organization.reload.is_invoiced?).to be_truthy
        expect(organization.paid_money?).to be_truthy
        expect(render_supporters?(organization)).to be_falsey
      end
    end
  end
end
