require "rails_helper"

RSpec.describe PrimaryActivity, type: :model do
  it_behaves_like "friendly_slug_findable"

  describe "factory" do
    let(:primary_activity) { FactoryBot.create(:primary_activity) }
    it "is valid" do
      expect(primary_activity).to be_valid
      expect(primary_activity.flavor?).to be_truthy
    end

    context "primary_activity_flavor_with_family" do
      let(:primary_activity) { FactoryBot.create(:primary_activity_flavor_with_family) }
      it "is has family" do
        expect(primary_activity).to be_valid
        expect(primary_activity.flavor?).to be_truthy
        expect(primary_activity.primary_activity_family_id).to be_present
        expect(primary_activity.primary_activity_family.family?).to be_truthy
      end
    end
  end
end
