require "rails_helper"

RSpec.describe CallbackJob::AddressRecordUpdateAssociationsJob, type: :job do
  let(:instance) { described_class.new }

  context "user" do
    let(:user) { FactoryBot.create(:user) }
    let!(:address_record) { FactoryBot.create(:address_record, :edmonton, user:, kind: :user) }

    it "assigns the user coordinates" do
      # creation enqueues this job
      expect(described_class.jobs.map { |j| j["args"] }.flatten).to eq([address_record.id])

      expect(user.reload.latitude).to be_blank
      expect(user.address_record_id).to be_blank
      expect(address_record.reload.latitude).to be_present

      instance.perform(address_record.id)

      expect(address_record.reload.to_coordinates.any?).to be_truthy
      expect(user.reload.to_coordinates).to eq address_record.to_coordinates
      expect(user.address_record_id).to eq address_record.id
    end
    context "with user with a different address_record" do
      let(:user) { FactoryBot.create(:user, :with_address_record) }

      it "does not assign the user coordinates" do
        # Tests for :with_address_record factory
        expect(user.reload.address_record).to be_present
        expect(user.address_record.kind).to eq "user"
        expect(user.to_coordinates).to eq user.address_record.to_coordinates
        expect(user.address_record.user_id).to eq user.id

        instance.perform(address_record.id)

        expect(address_record.reload.to_coordinates.any?).to be_truthy
        expect(user.reload.to_coordinates).to_not eq address_record.to_coordinates
      end
    end
  end

  context "location" do
    include_context :geocoder_default_location

    let(:location) { FactoryBot.create(:location, :with_address_record, address_in: :new_york) }
    let(:address_record) { location.address_record }
    let(:target_coordinates) { default_location.slice(:latitude, :longitude).values }

    it "assigns the location coordinates" do
      location.update_columns(latitude: nil, longitude: nil)
      expect(location.reload.to_coordinates.compact).to eq([])
      expect(address_record.reload.to_coordinates.compact).to eq target_coordinates
      expect(address_record.kind).to eq "organization"

      instance.perform(address_record.id)

      expect(location.reload.to_coordinates.compact).to eq target_coordinates
      expect(address_record.reload.to_coordinates.compact).to eq target_coordinates
    end
  end
end
