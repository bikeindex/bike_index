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
    let(:ascend_bike) { FactoryBot.create(:bike_ascend_pos) }
    let(:organization) { ascend_bike.organizations.first }
    it "schedules all the workers" do
      organization.reload
      expect(organization.pos_kind).to eq "not_pos"
      instance.perform
      organization.reload
      expect(organization.pos_kind).to eq "ascend_pos"
    end
  end
end
