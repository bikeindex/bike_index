# frozen_string_literal: true

require "rails_helper"

RSpec.describe VehicleSpecification, type: :model do
  describe "bikebook_model" do
    let(:bikebook_model) do
      BikebookModel.create!(catalog_id: "m/specialized/2020/dropped", manufacturer: FactoryBot.create(:manufacturer),
        name: "Dropped", model_slug: "dropped", first_year: 2020)
    end
    let(:vehicle_specification) { VehicleSpecification.create!(bike_obj: FactoryBot.create(:bike), bikebook_model:) }

    it "is the model after the catalog drops it" do
      bikebook_model.destroy
      expect(vehicle_specification.reload.bikebook_model).to eq bikebook_model
    end
  end
end
