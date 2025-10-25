require "rails_helper"

RSpec.shared_examples "address_recorded" do
  let(:model_sym) { subject.class.name.underscore.to_sym }
  let(:instance) { FactoryBot.create(model_sym, address_record:, latitude: nil, longitude: nil) }
  let(:address_record) { FactoryBot.create(:address_record) }

  describe "Callbacks::AddressRecordUpdateAssociationsJob updates" do
    let(:job) { Callbacks::AddressRecordUpdateAssociationsJob }

    it "is updated from the job" do
      # bikes handling is via BikeServices::CalculateStoredLocation
      unless subject.instance_of?(Bike)
        expect(address_record).to be_valid

        expect do
          address_record.update(street: "something")
        end.to change(job.jobs, :size).by(1)

        # users have specific handling - which is tested in the job spec
        unless subject.instance_of?(User)

          expect(instance.address_record.id).to eq address_record.id
          expect(address_record.reload.to_coordinates.any?).to be_truthy

          # MarketplaceListing sets latitude from the passed address_record on save -
          # but the job needs to update the associations, because the address record may change independently
          if instance.latitude.present?
            instance.update_columns(latitude: nil, longitude: nil)
            instance.reload
          end
          expect(instance.to_coordinates.any?).to be_falsey

          job.new.perform(address_record.id)

          expect(instance.reload.to_coordinates).to eq address_record.to_coordinates
        end
      end
    end
  end

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
