require "rails_helper"

RSpec.describe CallbackJobs::AfterRegistrationSequenceChangeJob, type: :job do
  let(:instance) { described_class.new }
  let(:organization) { FactoryBot.create(:organization) }
  let!(:registration_sequence) { FactoryBot.create(:registration_sequence_active, :with_pages, organization:) }
  let!(:b_param) { pending_b_param(organization) }
  let!(:b_param_other_organization) { pending_b_param(FactoryBot.create(:organization)) }

  def pending_b_param(organization)
    BParam.create(origin: "register_flow", created_bike_id: FactoryBot.create(:bike, :with_ownership).id,
      params: {bike: {creation_organization_id: organization.id}, acknowledgment_pending: true}.as_json)
  end

  it "finishes the organization's pending registrations once it has no active sequence" do
    Sidekiq::Job.clear_all
    registration_sequence.update(end_at: Time.current)
    expect(described_class.jobs.map { it["args"] }).to eq([[registration_sequence.id]])

    instance.perform(registration_sequence.id)
    expect(b_param.reload.acknowledgment_pending?).to be_falsey
    expect(b_param.finished_registration?).to be_truthy
    expect(b_param_other_organization.reload.acknowledgment_pending?).to be_truthy
    expect(EmailJobs::OwnershipInvitationJob.jobs.map { it["args"] }).to eq([[b_param.created_bike.current_ownership.id]])
  end

  context "with a new sequence activated in its place" do
    it "leaves the registrations pending" do
      FactoryBot.create(:registration_sequence, :with_pages, organization:).make_active!
      expect(registration_sequence.reload.archived?).to be_truthy

      instance.perform(registration_sequence.id)
      expect(b_param.reload.acknowledgment_pending?).to be_truthy
    end
  end

  context "with the template" do
    it "doesn't enqueue" do
      Sidekiq::Job.clear_all
      FactoryBot.create(:registration_sequence_template_active)
      expect(described_class.jobs.count).to eq 0
    end
  end
end
