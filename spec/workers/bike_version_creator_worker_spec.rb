require "rails_helper"

RSpec.describe BikeVersionCreatorWorker, type: :job do
  let(:instance) { described_class.new }

  let(:bike) { FactoryBot.create(:bike, :with_ownership_claimed) }
  let(:user) { bike.user }
  it "creates the bike_version" do
    expect(bike.reload.bike_versions.count).to eq 1
    expect {
      instance.perform(bike.id)
    }.to change(BikeVersion, :count).by 1
    expect(bike.reload.bike_versions.count).to eq 1
    bike_version = bike.bike_versions.first
    expect(bike_version.user_id).to eq user.id
    expect(bike_version.authorized?(user)).to be_truthy
    expect(bike_version.mnfg_name).to eq bike.mnfg_name
    expect(bike_version.frame_colors).to eq bike.frame_colors
  end
  context "with all the associations and components" do
    it "creates"
  end
end
