require "rails_helper"

RSpec.describe Admin::CtypesController, type: :request do
  base_url = "/admin/ctypes"

  context "given a logged-in superuser" do
    include_context :request_spec_logged_in_as_superuser

    describe "index" do
      let!(:ctype_a) { FactoryBot.create(:ctype, name: "Axle", cgroup: FactoryBot.create(:cgroup, name: "Wheels")) }
      let!(:ctype_b) { FactoryBot.create(:ctype, name: "Brakes", cgroup: FactoryBot.create(:cgroup, name: "Additional parts")) }

      it "renders and sorts by the requested column and direction" do
        get base_url
        expect(response).to be_ok
        expect(response).to render_template(:index)

        get base_url, params: {sort: "name", direction: "asc"}
        expect(assigns(:ctypes).pluck(:id)).to eq([ctype_a.id, ctype_b.id])

        get base_url, params: {sort: "name", direction: "desc"}
        expect(assigns(:ctypes).pluck(:id)).to eq([ctype_b.id, ctype_a.id])

        # Sorts by component group name, not the cgroup_id foreign key
        get base_url, params: {sort: "cgroup", direction: "asc"}
        expect(assigns(:ctypes).pluck(:id)).to eq([ctype_b.id, ctype_a.id])
      end
    end
  end
end
