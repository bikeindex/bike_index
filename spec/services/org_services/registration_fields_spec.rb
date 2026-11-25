require "rails_helper"

RSpec.describe OrgServices::RegistrationFields do
  let(:organization) do
    FactoryBot.create(:organization_with_organization_features, enabled_feature_slugs: %w[reg_organization_affiliation reg_student_id],
      registration_field_labels: {reg_student_id: "Campus <b>ID</b>"})
  end
  let(:bike) { FactoryBot.create(:bike_organized, :with_ownership_claimed, creation_organization: organization) }
  before do
    bike.current_ownership.update(registration_info: {"organization_affiliation" => "graduate_student", "student_id" => "JD_4821"})
  end

  describe "rows" do
    it "labels the fields the organization collects, in the order asked" do
      rows = described_class.rows(bike: bike.reload, organization:,
        reg_fields: %w[reg_student_id reg_phone reg_organization_affiliation])

      expect(rows).to eq([["Campus ID", "JD_4821"], ["Organization affiliation", "Graduate student"]])
    end
  end
end
