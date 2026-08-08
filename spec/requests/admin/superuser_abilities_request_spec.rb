require "rails_helper"

base_url = "/admin/superuser_abilities"
RSpec.describe Admin::SuperuserAbilitiesController, type: :request do
  include_context :request_spec_logged_in_as_superuser
  let(:user_subject) { FactoryBot.create(:user) }
  let!(:superuser_ability) { SuperuserAbility.create(user: user_subject) }

  describe "index" do
    it "renders" do
      get base_url
      expect(response.status).to eq(200)
      expect(response).to render_template(:index)
      expect(assigns(:collection).pluck(:id)).to include(superuser_ability.id)
    end
  end

  describe "new" do
    it "renders, with each field's helper text describing it" do
      get "#{base_url}/new"
      expect(response.status).to eq(200)
      expect(response).to render_template(:new)
      body = Nokogiri::HTML(response.body)
      expect(body.at_css("p#superuser_ability_controller_name_helper").to_html).to include("<em>leave blank</em>")
      expect(body.at_css("#superuser_ability_controller_name")["aria-describedby"])
        .to eq "superuser_ability_controller_name_helper"
    end
  end

  describe "create" do
    let(:new_user) { FactoryBot.create(:user_confirmed) }

    it "creates" do
      expect {
        post base_url, params: {
          superuser_ability: {user_identifier: new_user.email, controller_name: "bikes", action_name: "edit"},
          no_hide_spam: 1
        }
      }.to change(SuperuserAbility, :count).by 1

      superuser_ability = SuperuserAbility.last
      expect(response).to redirect_to(edit_admin_superuser_ability_path(superuser_ability))
      expect(superuser_ability.user_id).to eq new_user.id
      expect(superuser_ability.kind).to eq "action"
      expect(superuser_ability.controller_name).to eq "bikes"
      expect(superuser_ability.action_name).to eq "edit"
      expect(superuser_ability.su_options).to eq(%w[no_hide_spam])
    end

    context "with blank controller_name" do
      it "creates a universal ability" do
        expect {
          post base_url, params: {
            superuser_ability: {user_identifier: new_user.username, controller_name: "", action_name: ""}
          }
        }.to change(SuperuserAbility, :count).by 1

        superuser_ability = SuperuserAbility.last
        expect(superuser_ability.user_id).to eq new_user.id
        expect(superuser_ability.kind).to eq "universal"
        expect(superuser_ability.controller_name).to be_nil
        expect(superuser_ability.su_options).to eq([])
      end
    end

    context "with an unmatched user" do
      it "renders new" do
        expect {
          post base_url, params: {superuser_ability: {user_identifier: "nobody@example.com"}}
        }.to_not change(SuperuserAbility, :count)
        expect(response).to render_template(:new)
      end
    end
  end

  describe "edit" do
    it "renders" do
      get "#{base_url}/#{superuser_ability.id}/edit"
      expect(response.status).to eq(200)
      expect(response).to render_template(:edit)
    end
  end

  describe "update" do
    it "updates" do
      expect(superuser_ability.reload.su_options).to eq([])
      put "#{base_url}/#{superuser_ability.id}", params: {
        no_always_show_credibility: 1,
        no_hide_spam: 1
      }
      superuser_ability.reload
      expect(superuser_ability.reload.su_options).to eq(%w[no_always_show_credibility no_hide_spam])
    end
  end
end
