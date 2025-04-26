require "rails_helper"

RSpec.shared_examples "address_recorded" do
  let(:model_sym) { subject.class.name.underscore.to_sym }
  let(:instance) { FactoryBot.create(model_sym, address_record:, latitude: nil, longitude: nil) }
  let(:address_record) { FactoryBot.create(:address_record) }

  describe "Callbacks::AddressRecordUpdateAssociationsJob updates" do
    let(:job) { Callbacks::AddressRecordUpdateAssociationsJob }

    # users have specific handling - which is tested in the job spec
    unless subject.class.name == "User"
      it "is updated from the job" do
        expect(instance.address_record.id).to eq address_record.id
        expect(instance.to_coordinates.any?).to be_falsey
        expect(address_record.reload.to_coordinates.any?).to be_truthy

        job.new.perform(address_record.id)

        expect(instance.reload.to_coordinates).to eq address_record.to_coordinates
      end
    end
  end
end
