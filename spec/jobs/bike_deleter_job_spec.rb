require "rails_helper"

RSpec.describe BikeDeleterJob, type: :job do
  let(:instance) { described_class.new }

  let(:ownership) { FactoryBot.create(:ownership) }
  let!(:bike) { ownership.bike }
  let!(:public_image) { FactoryBot.create(:public_image, imageable: bike) }

  it "deletes a bike and associations, doesn't error if bike is deleted already" do
    expect {
      instance.perform(bike.id)
      # Running it again doesn't error
      instance.perform(bike.id)
    }.to change(Bike, :count).by(-1).and change(Ownership, :count).by(0).and change(PublicImage, :count).by(0)
    expect(Bike.unscoped.find_by_id(bike.id)).to be_present
    bike.reload
    expect(bike.deleted?).to be_truthy
    # And it didn't delete ownership or public_image
    expect(Ownership.where(id: ownership.id).count).to eq 1
    expect(PublicImage.find_by_id(public_image.id)).to be_present
  end

  context "with marketplace_listing" do
    let!(:marketplace_listing) { FactoryBot.create(:marketplace_listing, :for_sale) }
    let!(:bike) { marketplace_listing.item }

    it "marks marketplace_listing as removed" do
      expect(marketplace_listing.status).to eq "for_sale"
      instance.perform(bike.id)
      expect(marketplace_listing.reload.status).to eq "removed"
    end
  end

  context "with current_impound_record" do
    let!(:impound_record) { FactoryBot.create(:impound_record, bike:) }
    let(:user) { FactoryBot.create(:user) }

    it "creates impound_record_update with removed_from_bike_index" do
      expect(bike.reload.current_impound_record).to eq impound_record
      expect {
        instance.perform(bike.id, false, user.id)
      }.to change(ImpoundRecordUpdate, :count).by(1)
      impound_update = impound_record.impound_record_updates.last
      expect(impound_update.kind).to eq "removed_from_bike_index"
      expect(impound_update.user_id).to eq user.id
    end
  end

  context "really delete" do
    let(:bike_id) { bike.id }
    let(:public_image_id) { public_image.id }

    it "really deletes the bike, ownership, and public_image" do
      expect {
        instance.perform(bike_id, true)
        # Running it again doesn't error
        instance.perform(bike_id, true)
      }.to change(Bike, :count).by(-1).and change(Ownership, :count).by(-1).and change(PublicImage, :count).by(-1)
      expect(Bike.unscoped.find_by_id(bike_id)).to be_nil
      expect(Ownership.where(id: ownership.id).count).to eq 0
      expect(PublicImage.find_by_id(public_image_id)).to be_nil
    end
  end
end
