require "rails_helper"

RSpec.shared_examples "address_recorded" do
  let(:model_sym) { subject.class.name.underscore.to_sym }
  let(:instance) { FactoryBot.create(model_sym, address_record:, latitude: nil, longitude: nil) }
  let(:address_record) { FactoryBot.create(:address_record) }

  describe "CallbackJob::AddressRecordUpdateAssociationsJob updates" do
    let(:job) { CallbackJob::AddressRecordUpdateAssociationsJob }

    it "is updated from the job" do
      # bikes handling is via BikeServices::CalculateLocation
      unless subject.instance_of?(Bike) || subject.instance_of?(ImpoundRecord)
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
end
