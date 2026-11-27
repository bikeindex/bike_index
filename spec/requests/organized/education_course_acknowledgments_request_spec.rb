require "rails_helper"

RSpec.describe Organized::EducationCourseAcknowledgmentsController, type: :request do
  let(:base_url) { "/o/#{current_organization.to_param}/education_course_acknowledgments" }

  include_context :request_spec_logged_in_as_organization_user

  describe "index" do
    it "redirects without education_courses" do
      get base_url
      expect(response).to redirect_to organization_root_path(organization_id: current_organization.to_param)
      expect(flash[:error]).to be_present
    end

    context "with education_courses" do
      let(:current_organization) do
        FactoryBot.create(:organization_with_organization_features, enabled_feature_slugs: ["education_courses"])
      end
      let(:bike) { FactoryBot.create(:bike_lightspeed_pos, creation_organization: current_organization, created_at: 3.days.ago) }
      let(:education_course) { FactoryBot.create(:education_course_active, organization: current_organization) }
      let!(:acknowledgment) do
        FactoryBot.create(:education_course_acknowledgment, education_course:, bike:,
          owner_email: "agreed@example.com", acknowledged_at: 2.days.ago)
      end
      # The default course, standing in for the organization's on one of its bikes
      let!(:default_acknowledgment) do
        FactoryBot.create(:education_course_acknowledgment, owner_email: "defaulted@example.com",
          education_course: FactoryBot.create(:education_course_default_active),
          bike: FactoryBot.create(:bike_organized, creation_organization: current_organization, created_at: 2.days.ago))
      end
      let!(:pending) do
        FactoryBot.create(:education_course_acknowledgment_pending, education_course:, owner_email: "pending@example.com",
          bike: FactoryBot.create(:bike_organized, creation_organization: current_organization, created_at: 1.day.ago))
      end
      let!(:other_organization_acknowledgment) do
        FactoryBot.create(:education_course_acknowledgment, owner_email: "elsewhere@example.com",
          bike: FactoryBot.create(:bike_organized))
      end

      def emails = response.body.scan(/(\w+)@example\.com/).flatten

      it "lists the acknowledgments on the organization's bikes, unfinished ones too" do
        get base_url
        expect(response).to be_ok
        expect(response.body).to include("E-Vehicle Education Acknowledgments", "Unfinished")
        expect(response.body).to match(/3<\/span> matching acknowledgments/)
        expect(response.body).to include("/bikes/#{bike.id}?organization_id=#{current_organization.to_param}")
        # Source, the registration's origin
        expect(response.body).to match(/>\s*lightspeed\s*</).and match(/>\s*web\s*</)
        expect(emails).to eq %w[pending defaulted agreed]

        get base_url, params: {sort: "acknowledged_at", direction: "asc"}
        expect(emails).to eq %w[agreed defaulted pending]

        get base_url, params: {sort: "owner_email", direction: "asc"}
        expect(emails).to eq %w[agreed defaulted pending]

        get base_url, params: {search_status: "acknowledged"}
        expect(emails).to eq %w[defaulted agreed]

        get base_url, params: {search_status: "unfinished"}
        expect(emails).to eq %w[pending]

        # The period is of the registrations
        get base_url, params: {period: "custom", start_time: 50.hours.ago.to_i}
        expect(emails).to eq %w[pending defaulted]
      end
    end
  end
end
