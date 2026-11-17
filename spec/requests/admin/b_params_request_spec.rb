require "rails_helper"

base_url = "/admin/b_params"
RSpec.describe base_url, type: :request do
  include_context :request_spec_logged_in_as_superuser
  let!(:subject) { FactoryBot.create(:b_param) }

  describe "index" do
    it "responds with OK and renders the index template" do
      get base_url
      expect(response.code).to eq("200")
      expect(response).to render_template(:index)
      get "#{base_url}?query=something"
      expect(response).to render_template :index
    end

    context "with an organization and a created bike" do
      let(:organization) { FactoryBot.create(:organization) }
      let(:bike) { FactoryBot.create(:bike) }
      let!(:subject) do
        FactoryBot.create(:b_param_with_creation_organization, organization:, origin: "embed_partial")
      end

      before { subject.update(created_bike_id: bike.id, bike_errors: ["frame_material is not valid"]) }

      it "renders the row's links, origin, errors and params" do
        get "#{base_url}?period=all"

        expect(response.code).to eq("200")
        expect(response.body).to match(%r{/admin/b_params/#{subject.id}})
        expect(response.body).to match(%r{/admin/users/#{subject.creator_id}})
        expect(response.body).to match(%r{/admin/organizations/#{organization.id}})
        expect(response.body).to match(%r{/admin/bikes/#{bike.id}})
        expect(response.body).to match(/old landing page/)
        expect(response.body).to match(/Frame material is not valid/)
        expect(response.body).to_not match(/owner_email/)

        get "#{base_url}?period=all&search_show_data=true"
        expect(response.body).to match(/owner_email/)
      end
    end

    context "with a register flow registration" do
      let!(:subject) { FactoryBot.create(:b_param_unfinished_registration) }

      it "renders the step it's at" do
        get base_url

        expect(response.code).to eq("200")
        expect(response.body).to include("Step 2")
      end
    end

    context "with education courses in progress and agreed to" do
      let(:in_progress_params) { {education_course: {id: 12, acknowledged_page_ids: [1]}} }
      let!(:in_progress) { FactoryBot.create(:b_param, params: in_progress_params) }
      let!(:agreed) { FactoryBot.create(:b_param, params: in_progress_params) }
      let!(:acknowledgment) { FactoryBot.create(:education_course_acknowledgment, b_param: agreed) }
      let!(:acknowledgment_without_b_param) { FactoryBot.create(:education_course_acknowledgment) }

      it "filters to the courses in progress" do
        get base_url, params: {search_education_course_in_progress: true}

        expect(response.code).to eq("200")
        expect(assigns(:b_params).map(&:id)).to eq([in_progress.id])
      end
    end
  end

  describe "show" do
    it "responds with OK and renders the show template" do
      get "#{base_url}/#{subject.to_param}"

      expect(response.code).to eq("200")
      expect(response).to render_template(:show)
      expect(response.body).to_not match(/bike errors/i)
    end

    context "with bike_errors" do
      before { subject.update(bike_errors: ["Frame material is not valid"]) }

      it "renders them" do
        get "#{base_url}/#{subject.to_param}"

        expect(response.code).to eq("200")
        expect(response.body).to match(/bike errors/i)
        expect(response.body).to match(/Frame material is not valid/)
      end
    end
  end
end
