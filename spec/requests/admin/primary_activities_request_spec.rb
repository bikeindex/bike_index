require "rails_helper"

RSpec.describe Admin::PrimaryActivitiesController, type: :request do
  base_url = "/admin/primary_activities"

  context "given a logged-in superuser" do
    include_context :request_spec_logged_in_as_superuser
    let!(:primary_activity) { FactoryBot.create(:primary_activity) }

    describe "index" do
      it "responds with 200 OK and renders the index template" do
        get base_url
        expect(response).to be_ok
        expect(response).to render_template(:index)
      end
    end
    context "edit" do
      it "renders" do
        get "#{base_url}/#{primary_activity.id}/edit"
        expect(response).to be_ok
        expect(response).to render_template(:edit)
      end
    end
    context "update" do
      it "updates" do
        patch "#{base_url}/#{primary_activity.id}", params: {
          primary_activity: {priority: 12, name: "FUCK"}
        }
        expect(flash[:success]).to be_present
        expect(primary_activity.reload.priority).to eq 12
        expect(primary_activity.name).to_not eq "FUCK"
      end
    end
  end
end
