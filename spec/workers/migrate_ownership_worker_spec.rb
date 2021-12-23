require "rails_helper"

RSpec.describe MigrateOwnershipWorker, type: :job do
  let(:instance) { described_class.new }

  let(:ownership) { FactoryBot.create(:ownership, registration_info: {organization_affiliation: "community_member"}) }
  let!(:bike) { ownership.bike }
  it "updates the soon_current_ownership_id" do
    bike.reload
    expect(bike.reload.soon_current_ownership_id).to be_blank
    instance.perform(bike.id)
    bike.reload
    expect(bike.reload.soon_current_ownership_id).to eq ownership.id
    expect(ownership.reload.registration_info).to eq({organization_affiliation: "community_member"}.as_json)
  end
  context "conditional_information" do
    it "updates registration_info" do
      bike.update_column :conditional_information, {student_id: "ABC-ID"}
      expect(ownership.reload.registration_info).to eq({organization_affiliation: "community_member"}.as_json)
      expect(bike.reload.soon_current_ownership_id).to be_blank
      instance.perform(bike.id)
      expect(bike.reload.soon_current_ownership_id).to eq ownership.id
      expect(ownership.reload.registration_info).to eq({organization_affiliation: "community_member", student_id: "ABC-ID"}.as_json)
    end
  end
end
