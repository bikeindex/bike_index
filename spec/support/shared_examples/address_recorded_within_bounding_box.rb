require "rails_helper"

RSpec.shared_examples "address_recorded_within_bounding_box" do
  let(:model_sym) { subject.class.name.underscore.to_sym }
  let(:instance) { FactoryBot.create(model_sym, address_record:, latitude: nil, longitude: nil) }
  let(:address_record) { FactoryBot.create(:address_record) }

  describe "within_bounding_box" do
    # Directly assign coordinates, without using address record, for simplicity
    let!(:instance) { FactoryBot.create(model_sym, latitude: 34.05223, longitude: -118.24368) }
    let(:box_matching) { [33.91017581688915, -118.41733407395493, 34.19963938311085, -118.06795192604507] }
    let(:box_outside) { [33.91017581688915, -119.0, 34.19963938311085, -118.3] }
    let(:box_fail) { [] } # This is the return for an unknown bounding box

    it "responds with records inside the bounding box" do
      expect(instance.reload.latitude).to eq 34.05223
      expect(subject.class.within_bounding_box(box_matching).pluck(:id)).to eq([instance.id])
      expect(subject.class.within_bounding_box(box_outside).pluck(:id)).to eq([])
      expect(subject.class.within_bounding_box(box_fail).pluck(:id)).to eq([])
    end
  end
end
