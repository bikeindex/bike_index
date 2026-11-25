require "rails_helper"

RSpec.describe CallbackJobs::AfterEducationCourseChangeJob, type: :job do
  let(:instance) { described_class.new }
  let(:organization) { FactoryBot.create(:organization) }
  let!(:education_course) { FactoryBot.create(:education_course_active, :with_pages, organization:) }
  let!(:b_param) { pending_b_param(education_course) }
  let!(:b_param_other_organization) { pending_b_param(FactoryBot.create(:education_course_active)) }

  # Pending against the organization's own course, the way create_pending makes it
  def pending_b_param(course)
    bike = FactoryBot.create(:bike, :with_ownership)
    BParam.create(origin: "register_flow", created_bike_id: bike.id,
      params: {bike: {creation_organization_id: course.organization_id}}.as_json)
      .tap { FactoryBot.create(:education_course_acknowledgment_pending, b_param: it, bike:, education_course: course) }
  end

  it "finishes the organization's pending registrations once it has no active course" do
    Sidekiq::Job.clear_all
    education_course.update(end_at: Time.current)
    expect(described_class.jobs.map { it["args"] }).to eq([[education_course.id]])

    # Deleted, not acknowledged - nothing was agreed to
    expect { instance.perform(education_course.id) }.to change(EducationCourseAcknowledgment, :count).by(-1)
    expect(EducationCourseAcknowledgment.acknowledged.count).to eq 0
    expect(b_param.reload.acknowledgment_pending?).to be_falsey
    expect(b_param.finished_registration?).to be_truthy
    expect(b_param_other_organization.reload.acknowledgment_pending?).to be_truthy
    expect(EmailJobs::OwnershipInvitationJob.jobs.map { it["args"] }).to eq([[b_param.created_bike.current_ownership.id]])
  end

  context "with the organization destroyed" do
    it "finishes them too, reaching the course it soft-deleted" do
      organization.destroy
      expect(education_course.reload.deleted?).to be_truthy

      expect { instance.perform(education_course.id) }
        .to change(EducationCourseAcknowledgment.pending, :count).by(-1)
      expect(b_param.reload.finished_registration?).to be_truthy
      expect(b_param_other_organization.reload.acknowledgment_pending?).to be_truthy
    end
  end

  context "with a new course activated in its place" do
    it "leaves the registrations pending" do
      FactoryBot.create(:education_course, :with_pages, organization:).make_active!
      expect(education_course.reload.archived?).to be_truthy

      instance.perform(education_course.id)
      expect(b_param.reload.acknowledgment_pending?).to be_truthy
    end
  end

  context "with the default course" do
    let(:default_course) { FactoryBot.create(:education_course_default_active, :with_pages) }
    let!(:b_param_default) { pending_b_param(default_course) }

    it "finishes its pending registrations once it's ended, without touching an organization's" do
      Sidekiq::Job.clear_all
      default_course.update(end_at: Time.current)
      expect(described_class.jobs.map { it["args"] }).to eq([[default_course.id]])

      instance.perform(default_course.id)
      expect(b_param_default.reload.acknowledgment_pending?).to be_falsey
      expect(b_param.reload.acknowledgment_pending?).to be_truthy
      expect(EmailJobs::OwnershipInvitationJob.jobs.map { it["args"] }).to eq([[b_param_default.created_bike.current_ownership.id]])
    end

    it "leaves them pending when a new one replaces it" do
      FactoryBot.create(:education_course_default, :with_pages).make_active!
      expect(default_course.reload.archived?).to be_truthy

      instance.perform(default_course.id)
      expect(b_param_default.reload.acknowledgment_pending?).to be_truthy
    end
  end
end
