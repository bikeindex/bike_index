require "rails_helper"

RSpec.describe Admin::AmbassadorTasksController, type: :controller do
  context "given an authenticated super admin" do
    include_context :logged_in_as_super_admin

    describe "#index" do
      it "renders the index template" do
        get :index

        expect(response.status).to eq(200)
        expect(response).to render_template(:index)
        expect(flash).to_not be_present
      end
    end

    describe "#new" do
      it "renders the new template" do
        get :new

        expect(response.status).to eq(200)
        expect(response).to render_template(:new)
        expect(flash).to_not be_present
      end
    end

    describe "#edit" do
      it "renders the edit template with the found ambassador task" do
        get :edit, params: { id: FactoryBot.create(:ambassador_task).id }

        expect(response.status).to eq(200)
        expect(response).to render_template(:edit)
        expect(flash).to_not be_present
      end
    end

    describe "#create" do
      it "creates the given ambassador task" do
        ambassador_task = FactoryBot.attributes_for(:ambassador_task)
        expect(AmbassadorTask.count).to eq(0)

        post :create, params: { ambassador_task: ambassador_task }

        expect(response).to redirect_to(admin_ambassador_tasks_url)
        expect(flash).to_not be_present
        expect(AmbassadorTask.count).to eq(1)
      end
    end

    describe "#update" do
      it "updates the given ambassador task" do
        ambassador_task = FactoryBot.create(:ambassador_task, description: "old text")

        patch :update,
              params: {
                id: ambassador_task.id,
                ambassador_task: { description: "new text" }
              }

        expect(response).to redirect_to(admin_ambassador_tasks_url)
        expect(flash).to_not be_present
        expect(AmbassadorTask.first.description).to eq("new text")
      end
    end

    describe "#destroy" do
      it "deletes the given ambassador task" do
        ambassador_task1 = FactoryBot.create(:ambassador_task)
        ambassador_task2 = FactoryBot.create(:ambassador_task)

        delete :destroy, params: { id: ambassador_task2.id }

        expect(response).to redirect_to(admin_ambassador_tasks_url)
        expect(AmbassadorTask.all).to eq([ambassador_task1])
      end
    end
  end

  context "given an authenticated non-superadmin" do
    include_context :logged_in_as_user
    it { expect(get(:index)).to redirect_to(user_home_url) }
    it { expect(get(:new)).to redirect_to(user_home_url) }
    it { expect(get(:edit, params: { id: 1 })).to redirect_to(user_home_url) }
    it { expect(post(:create)).to redirect_to(user_home_url) }
    it { expect(put(:update, params: { id: 1 })).to redirect_to(user_home_url) }
    it { expect(delete(:destroy, params: { id: 1 })).to redirect_to(user_home_url) }
  end
end
