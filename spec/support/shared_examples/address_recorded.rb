require "rails_helper"

RSpec.shared_examples "address_recorded" do
  let(:model_sym) { subject.class.name.underscore.to_sym }
  let(:instance) { FactoryBot.create(model_sym, address_record:, latitude: nil, longitude: nil) }
  let(:address_record) { FactoryBot.create(:address_record) }

  describe "Callbacks::AddressRecordUpdateAssociationsJob updates" do
    let(:job) { Callbacks::AddressRecordUpdateAssociationsJob }

    it "is updated from the job" do
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
