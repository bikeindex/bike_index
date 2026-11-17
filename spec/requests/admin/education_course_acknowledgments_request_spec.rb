require "rails_helper"

base_url = "/admin/education_course_acknowledgments"
RSpec.describe Admin::EducationCourseAcknowledgmentsController, type: :request do
  context "given a logged-in superuser" do
    include_context :request_spec_logged_in_as_superuser

    let(:organization) { FactoryBot.create(:organization) }
    let(:education_course) { FactoryBot.create(:education_course_active, organization:) }
    let(:bike) { FactoryBot.create(:bike) }
    let(:other_user) { FactoryBot.create(:user) }
    let!(:acknowledgment) do
      FactoryBot.create(:education_course_acknowledgment, education_course:, bike:, user: other_user,
        owner_email: "agreed@example.com")
    end
    let!(:pending) { FactoryBot.create(:education_course_acknowledgment_pending) }

    def collection_ids = assigns(:collection).map(&:id)

    describe "index" do
      it "renders and filters" do
        get base_url
        expect(response).to be_ok
        expect(collection_ids).to match_array([acknowledgment.id, pending.id])
        expect(response.body).to include("agreed@example.com")
        expect(response.body).to include("#{base_url}?organization_id=#{organization.id}\"")
        expect(response.body).to include("/admin/b_params?search_education_course_in_progress=true")

        get base_url, params: {search_status: "pending"}
        expect(collection_ids).to eq([pending.id])

        get base_url, params: {search_status: "acknowledged"}
        expect(collection_ids).to eq([acknowledgment.id])

        get base_url, params: {sort: "acknowledged_at"}
        expect(collection_ids).to eq([acknowledgment.id, pending.id])

        get base_url, params: {sort: "acknowledged_at", search_status: "pending"}
        expect(collection_ids).to eq([pending.id])

        get base_url, params: {search_status: "destroy"}
        expect(collection_ids).to match_array([acknowledgment.id, pending.id])

        get base_url, params: {organization_id: organization.id, render_chart: true}
        expect(response).to be_ok
        expect(collection_ids).to eq([acknowledgment.id])

        get base_url, params: {search_education_course_id: pending.education_course_id}
        expect(collection_ids).to eq([pending.id])

        get base_url, params: {user_id: other_user.id}
        expect(collection_ids).to eq([acknowledgment.id])

        get base_url, params: {search_bike_id: bike.id}
        expect(collection_ids).to eq([acknowledgment.id])
      end

      context "with a soft-deleted organization and course" do
        before do
          organization.destroy
          education_course.destroy
        end

        it "still lists what was agreed to, without linking the missing course" do
          get base_url, params: {organization_id: organization.id}
          expect(response).to be_ok
          expect(collection_ids).to eq([acknowledgment.id])
          expect(response.body).to include("deleted!")
          expect(response.body).to_not include("href=\"/admin/education_courses/#{education_course.id}\"")
        end
      end
    end
  end
end
