require "rails_helper"

base_url = "/admin/ambassador_tasks"
RSpec.describe Admin::AmbassadorTasksController, type: :request do
  context "given an authenticated super admin" do
    include_context :request_spec_logged_in_as_superuser

    describe "#index" do
      it "renders the index template" do
        get base_url

        expect(response.status).to eq(200)
        expect(response).to render_template(:index)
        expect(flash).to_not be_present
      end
    end

    describe "#new" do
      it "renders the new template" do
        get "#{base_url}/new"

        expect(response.status).to eq(200)
        expect(response).to render_template(:new)
        expect(flash).to_not be_present
      end
    end

    describe "#edit" do
      it "renders the edit template with the found ambassador task" do
        get "#{base_url}/#{FactoryBot.create(:ambassador_task).id}/edit"

        expect(response.status).to eq(200)
        expect(response).to render_template(:edit)
        expect(flash).to_not be_present
      end
    end

    describe "#create" do
      it "creates the given ambassador task" do
        ambassador_task = FactoryBot.attributes_for(:ambassador_task)
        expect(AmbassadorTask.count).to eq(0)

        post base_url, params: {ambassador_task: ambassador_task}

        expect(response).to redirect_to(admin_ambassador_tasks_url)
        expect(flash).to_not be_present
        expect(AmbassadorTask.count).to eq(1)
      end
    end

    describe "#update" do
      it "updates the given ambassador task" do
        ambassador_task = FactoryBot.create(:ambassador_task, description: "old text")

        patch "#{base_url}/#{ambassador_task.id}",
          params: {ambassador_task: {description: "new text"}}

        expect(response).to redirect_to(admin_ambassador_tasks_url)
        expect(flash).to_not be_present
        expect(AmbassadorTask.first.description).to eq("new text")
      end
    end

    describe "#destroy" do
      it "deletes the given ambassador task" do
        ambassador_task1 = FactoryBot.create(:ambassador_task)
        ambassador_task2 = FactoryBot.create(:ambassador_task)

        delete "#{base_url}/#{ambassador_task2.id}"

        expect(response).to redirect_to(admin_ambassador_tasks_url)
        expect(AmbassadorTask.all).to eq([ambassador_task1])
      end
    end
  end

  context "given an authenticated non-superadmin" do
    include_context :request_spec_logged_in_as_user

    it "redirects to my_account_url" do
      get base_url

      expect(response).to redirect_to(my_account_url)
      expect(flash[:error]).to be_present
    end
  end
end
