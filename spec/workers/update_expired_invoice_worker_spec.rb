require "spec_helper"

describe UpdateOrganizationPosKindWorker, type: :lib do
  let(:subject) { UpdateOrganizationPosKindWorker }
  let(:instance) { subject.new }
  include_context :scheduled_worker
  include_examples :scheduled_worker_tests

  it "is the correct queue and frequency" do
    expect(subject.sidekiq_options["queue"]).to eq "low_priority" # overrides default
    expect(subject.frequency).to be > 6.hours
  end

  describe "perform" do
    let(:organization) { FactoryBot.create(:organization, kind: "bike_shop") }
    let!(:ascend_bike) { FactoryBot.create(:bike_ascend_pos, organization: organization) }
    it "schedules all the workers" do
      organization.reload
      ascend_bike.reload
      expect(organization.bikes).to eq([ascend_bike])
      expect(organization.pos_kind).to eq "not_pos"
      instance.perform
      organization.reload
      expect(organization.pos_kind).to eq "ascend_pos"
    end
  end
end
