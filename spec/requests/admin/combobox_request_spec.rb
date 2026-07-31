require "rails_helper"

RSpec.describe Admin::ComboboxController, type: :request do
  include_context :request_spec_logged_in_as_superuser

  describe "organization_chips" do
    let!(:organization) { FactoryBot.create(:organization, name: "Cool Bike Shop") }
    let!(:other_organization) { FactoryBot.create(:organization, name: "Bike Co-op") }

    it "renders a chip per value, in the order they were selected" do
      values = [other_organization.id, organization.id].join(",")
      post "/admin/combobox/organization_chips", params: {combobox_values: values, for_id: "test"}, as: :turbo_stream

      expect(response.code).to eq("200")
      expect(response.body).to include("Cool Bike Shop")
      expect(response.body.index("Bike Co-op")).to be < response.body.index("Cool Bike Shop")
    end

    context "with a deleted organization" do
      before { organization.destroy }

      it "still renders its chip" do
        post "/admin/combobox/organization_chips",
          params: {combobox_values: organization.id.to_s, for_id: "test"}, as: :turbo_stream

        expect(response.body).to include("Cool Bike Shop")
      end
    end

    context "with blank values" do
      it "renders nothing" do
        post "/admin/combobox/organization_chips", params: {combobox_values: "", for_id: "test"}, as: :turbo_stream

        expect(response.code).to eq("200")
        expect(response.body).to_not match(/hw-combobox__chip/)
      end
    end
  end
end
