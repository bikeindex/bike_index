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
      let(:bike) { FactoryBot.create(:bike_organized, creation_organization: current_organization) }
      let(:education_course) { FactoryBot.create(:education_course_active, organization: current_organization) }
      let!(:acknowledgment) do
        FactoryBot.create(:education_course_acknowledgment, education_course:, bike:,
          owner_email: "agreed@example.com", acknowledged_at: 2.days.ago)
      end
      # The default course, standing in for the organization's on one of its bikes
      let!(:default_acknowledgment) do
        FactoryBot.create(:education_course_acknowledgment, owner_email: "defaulted@example.com",
          education_course: FactoryBot.create(:education_course_default_active),
          bike: FactoryBot.create(:bike_organized, creation_organization: current_organization))
      end
      let!(:pending) do
        FactoryBot.create(:education_course_acknowledgment_pending, education_course:, owner_email: "pending@example.com",
          bike: FactoryBot.create(:bike_organized, creation_organization: current_organization))
      end
      let!(:other_organization_acknowledgment) do
        FactoryBot.create(:education_course_acknowledgment, owner_email: "elsewhere@example.com",
          bike: FactoryBot.create(:bike_organized))
      end

      it "lists the completed acknowledgments on the organization's bikes" do
        get base_url
        expect(response).to be_ok
        expect(response.body).to include("E-Vehicle education")
        expect(response.body).to include("agreed@example.com", "defaulted@example.com")
        expect(response.body).to include("/bikes/#{bike.id}?organization_id=#{current_organization.to_param}")
        expect(response.body).to_not include("pending@example.com")
        expect(response.body).to_not include("elsewhere@example.com")
        expect(response.body.index("defaulted@example.com")).to be < response.body.index("agreed@example.com")

        get base_url, params: {sort: "acknowledged_at", direction: "asc"}
        expect(response.body.index("agreed@example.com")).to be < response.body.index("defaulted@example.com")
      end
    end
  end
end
