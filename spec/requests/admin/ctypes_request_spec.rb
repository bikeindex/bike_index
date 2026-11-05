require "rails_helper"

RSpec.describe Admin::CtypesController, type: :request do
  base_url = "/admin/ctypes"

  context "given a logged-in superuser" do
    include_context :request_spec_logged_in_as_superuser

    describe "index" do
      let!(:ctype_a) { FactoryBot.create(:ctype, name: "Axle", cgroup: FactoryBot.create(:cgroup, name: "Wheels")) }
      let!(:ctype_b) { FactoryBot.create(:ctype, name: "Brakes", cgroup: FactoryBot.create(:cgroup, name: "Additional parts")) }

      # Scope to our ctypes -- a leaked Ctype.other from another spec would flake a full-collection match
      let(:sorted_ids) { -> { assigns(:ctypes).pluck(:id) & [ctype_a.id, ctype_b.id] } }

      it "renders and sorts by the requested column and direction" do
        get base_url
        expect(response).to be_ok
        expect(response).to render_template(:index)

        get base_url, params: {sort: "name", direction: "asc"}
        expect(sorted_ids.call).to eq([ctype_a.id, ctype_b.id])

        get base_url, params: {sort: "name", direction: "desc"}
        expect(sorted_ids.call).to eq([ctype_b.id, ctype_a.id])

        # Sorts by component group name, not the cgroup_id foreign key
        get base_url, params: {sort: "cgroup", direction: "asc"}
        expect(sorted_ids.call).to eq([ctype_b.id, ctype_a.id])
      end
    end

    describe "new" do
      it "renders the component group select as required" do
        get "#{base_url}/new"
        expect(response).to be_ok
        expect(Capybara.string(response.body)).to have_css("label[for='ctype_cgroup_id'] + select#ctype_cgroup_id[required]")
      end
    end

    describe "create" do
      let(:cgroup) { FactoryBot.create(:cgroup) }

      it "requires a component group" do
        expect {
          post base_url, params: {ctype: {name: "Fender"}}
        }.not_to change(Ctype, :count)
        expect(response.status).to eq 422
        expect(response).to render_template(:new)

        post base_url, params: {ctype: {name: "Fender", cgroup_id: cgroup.id}}
        expect(response).to redirect_to(admin_ctypes_url)
        expect(Ctype.last.cgroup_id).to eq cgroup.id
      end
    end

    describe "update" do
      let(:ctype) { FactoryBot.create(:ctype) }

      it "doesn't remove the component group" do
        patch "#{base_url}/#{ctype.to_param}", params: {ctype: {cgroup_id: ""}}
        expect(response.status).to eq 422
        expect(ctype.reload.cgroup_id).to be_present
      end
    end
  end
end
