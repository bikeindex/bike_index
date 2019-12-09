require "rails_helper"

RSpec.describe UpdateAssociatedOrganizationsWorker, type: :job do
  let(:instance) { described_class.new }

  context "multiple organizations" do
    let!(:organization1) { FactoryBot.create(:organization, updated_at: Time.current - 1.hour) }
    let!(:organization2) { FactoryBot.create(:organization, updated_at: Time.current - 2.hours) }
    it "updates the passed organizations" do
      organization1.reload
      organization2.reload
      expect(organization1.updated_at).to be < Time.current - 30.minutes
      expect(organization2.updated_at).to be < Time.current - 30.minutes
      Sidekiq::Worker.clear_all
      instance.perform([organization1.id, organization2.id])
      # Make sure we don't reenqueue
      expect(UpdateAssociatedOrganizationsWorker.jobs.count).to eq 0
      organization1.reload
      organization2.reload
      expect(organization1.updated_at).to be_within(1).of Time.current
      expect(organization2.updated_at).to be_within(1).of Time.current
    end
  end

  context "regional organization" do
    let!(:regional_org) { FactoryBot.create(:organization, :in_nyc) }
    let!(:regional_parent) { FactoryBot.create(:organization_with_regional_bike_counts, :in_nyc, updated_at: Time.current - 1.hour) }
    it "updates the regional parent too" do
      regional_org.update_column :updated_at, Time.current - 1.hour
      regional_parent.update_column :updated_at, Time.current - 1.hour
      regional_org.reload
      regional_parent.reload
      expect(regional_org.updated_at).to be < Time.current - 30.minutes
      expect(regional_parent.updated_at).to be < Time.current - 30.minutes
      Sidekiq::Worker.clear_all
      instance.perform([regional_org.id])
      # Make sure we don't reenqueue
      expect(UpdateAssociatedOrganizationsWorker.jobs.count).to eq 0
      regional_org.reload
      regional_parent.reload
      expect(regional_org.updated_at).to be_within(1).of Time.current
      expect(regional_parent.updated_at).to be_within(1).of Time.current
    end
  end
end
