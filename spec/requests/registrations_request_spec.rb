require "rails_helper"

RSpec.describe RegistrationsController, type: :request do
  let(:current_user) { FactoryBot.create(:user_confirmed) }
  let(:auto_user) { FactoryBot.create(:organization_auto_user) }
  let(:organization) { auto_user.organizations.first }
  let(:base_url) { "/registrations" }

  def expect_render_without_xframe
    expect(response.status).to eq(200)
    expect(response.headers["X-Frame-Options"]).to be_blank
    expect(flash).to_not be_present
  end

  def expect_it_to_render_embed_correctly
    expect_render_without_xframe
    expect(response).to render_template(:embed)
  end

  def page_form_inputs(response_body)
    (response_body.scan(/<input.*>/i) + response_body.scan(/<select.*>/i)).map do |input_str|
      {
        str: input_str,
        value: input_str[/value="[^"]*/]&.gsub('value="', ""),
        name: input_str[/name="[^"]*/]&.gsub(/name="(b_param\[)?/i, "")&.tr("]", "")
      }
    end
  end

  describe "new" do
    include_context :request_spec_logged_in_as_user

    it "renders with the embeded form, no xframing" do
      get "#{base_url}/new", params: {organization_id: organization.id, stolen: true}
      expect(response).to render_template(:new)
      expect(response.status).to eq(200)
      expect(response.headers["X-Frame-Options"]).to eq "SAMEORIGIN"
      expect(flash).to_not be_present
    end
  end

  describe "embed" do
    let(:basic_field_names) do
      %w[commit creation_organization_id manufacturer_id owner_email primary_frame_color_id status]
    end

    context "no organization" do
      context "no user" do
        it "renders" do
          get "#{base_url}/embed", params: {stolen: true}
          expect_it_to_render_embed_correctly
          expect(assigns(:stolen)).to be_truthy
          expect(assigns(:creator)).to be_nil
          expect(assigns(:owner_email)).to be_nil
        end
      end
      context "with user" do
        include_context :request_spec_logged_in_as_user

        it "renders does not set creator" do
          get "#{base_url}/embed"
          expect_it_to_render_embed_correctly
          expect(assigns(:stolen)).to be_falsey
          expect(assigns(:creator)).to be_nil
          expect(assigns(:owner_email)).to eq current_user.email
        end
      end
    end
    context "with organization" do
      context "no user" do
        it "renders" do
          get "#{base_url}/embed", params: {
            organization_id: organization.to_param, simple_header: true, select_child_organization: true,
            skip_vehicle_select: 1
          }
          expect_it_to_render_embed_correctly
          expect(assigns(:stolen)).to be_falsey
          expect(assigns(:organization)).to eq organization
          expect(assigns(:selectable_child_organizations)).to eq []
          expect(assigns(:creator)).to be_nil
          expect(assigns(:simple_header)).to be_truthy
          expect(assigns(:vehicle_select)).to be_falsey
          # Since we're creating these in line, actually test the rendered body
          body = response.body

          inputs = page_form_inputs(body)
          expect(inputs.find { |i| i[:name] == "creation_organization_id" }[:value]).to eq organization.id.to_s
          expect(inputs.map { |i| i[:name] }.sort).to eq basic_field_names
          expect(body).to match(/register your bike/i)
        end
      end
      context "with user" do
        let!(:organization_child) { FactoryBot.create(:organization, parent_organization_id: organization.id) }
        include_context :request_spec_logged_in_as_user

        it "renders, testing variables" do
          expect(organization.save).to eq(true)

          get "#{base_url}/embed", params: {
            organization_id: organization.id, status: "status_stolen", select_child_organization: true,
            skip_vehicle_select: "true"
          }

          expect_it_to_render_embed_correctly
          # Since we're creating these in line, actually test the rendered body
          body = response.body
          # Owner email
          inputs = page_form_inputs(body)
          expect(inputs.find { |i| i[:name] == "owner_email" }[:value]).to eq current_user.email
          expect(inputs.map { |i| i[:name] }.sort).to match_array(basic_field_names)
          expect(body).to match(/register your bike/i)

          expect(assigns(:simple_header)).to be_falsey
          expect(assigns(:stolen)).to be_truthy
          expect(assigns(:organization)).to eq organization
          expect(assigns(:selectable_child_organizations)).to eq([organization_child])
          expect(assigns(:b_param).creation_organization_id).to be_nil
          expect(assigns(:creator)).to be_nil
          expect(assigns(:owner_email)).to eq current_user.email
          expect(assigns(:vehicle_select)).to be_falsey
        end
      end
      context "with vehicle_type" do
        let(:vehicle_field_names) { (basic_field_names + ["cycle_type", "propulsion_type_motorized"]).sort }
        it "renders" do
          get "#{base_url}/embed", params: {
            organization_id: organization.to_param,
            simple_header: "1"
          }
          expect_it_to_render_embed_correctly
          expect(assigns(:stolen)).to be_falsey
          expect(assigns(:organization)).to eq organization
          expect(assigns(:selectable_child_organizations)).to eq []
          expect(assigns(:creator)).to be_nil
          expect(assigns(:simple_header)).to be_truthy
          expect(assigns(:vehicle_select)).to be_truthy
          expect(assigns(:button)).to be_nil
          expect(assigns(:button_and_header)).to be_nil
          # Since we're creating these in line, actually test the rendered body
          body = response.body
          inputs = page_form_inputs(body)
          expect(inputs.find { |i| i[:name] == "creation_organization_id" }[:value]).to eq organization.id.to_s
          expect(inputs.map { |i| i[:name] }.sort).to eq vehicle_field_names
          expect(body).to match(/register your vehicle/i)
        end
      end
      context "with button" do
        let(:color) { "ee7e2c" }
        it "assigns button" do
          get "#{base_url}/embed?organization_id=#{organization.to_param}&simple_header=1&button=#{color}"

          expect_it_to_render_embed_correctly
          expect(assigns(:organization)).to eq organization
          expect(assigns(:selectable_child_organizations)).to eq []
          expect(assigns(:creator)).to be_nil
          expect(assigns(:simple_header)).to be_truthy
          expect(assigns(:button)).to eq "##{color}"
          expect(assigns(:button_and_header)).to be_nil
        end
        context "with button malicious" do
          let(:color) { "@user + 1233" }
          it "renders" do
            get "#{base_url}/embed?organization_id=#{organization.to_param}&simple_header=1&button=#{color}"
            expect_it_to_render_embed_correctly
            expect(assigns(:organization)).to eq organization
            expect(assigns(:selectable_child_organizations)).to eq []
            expect(assigns(:creator)).to be_nil
            expect(assigns(:simple_header)).to be_truthy
            expect(assigns(:button)).to eq "#user12"
            expect(assigns(:button_and_header)).to be_nil
          end
        end
      end
      context "with button_and_header" do
        it "assigns button" do
          get "#{base_url}/embed?organization_id=#{organization.to_param}&simple_header=1&button_and_header=696969"

          expect_it_to_render_embed_correctly
          expect(assigns(:organization)).to eq organization
          expect(assigns(:selectable_child_organizations)).to eq []
          expect(assigns(:creator)).to be_nil
          expect(assigns(:simple_header)).to be_truthy
          expect(assigns(:button_and_header)).to eq "#696969"
        end
      end
    end
  end
  describe "create" do
    let(:manufacturer) { FactoryBot.create(:manufacturer) }
    let(:color) { FactoryBot.create(:color) }
    context "invalid creation" do
      context "email not set, sets simple_header" do
        let(:attrs) do
          {
            manufacturer_id: manufacturer.id,
            status: "status_stolen",
            creator_id: 21,
            primary_frame_color_id: color.id,
            secondary_frame_color_id: 12,
            tertiary_frame_color_id: 222,
            creation_organization_id: 9292,
            cycle_type: "bike"
          }
        end
        it "does not create a bparam, rerenders new with all assigned values" do
          expect {
            post base_url, params: {simple_header: true, b_param: attrs}
          }.to change(BParam, :count).by 0
          expect_render_without_xframe
          expect(response).to render_template(:new) # Because it redirects since unsuccessful
          expect(assigns(:simple_header)).to be_truthy
          b_param = assigns(:b_param)
          expect(attrs.except(:creator_id, :cycle_type)).to have_attributes b_param
          expect(b_param.cycle_type).to eq "bike"
          expect(b_param.creator_id).to be_nil
          expect(b_param.origin).to eq "embed_partial"
        end
      end
    end
    context "valid creation" do
      context "nothing except email set - unverified authenticity token" do
        include_context :test_csrf_token
        it "creates a new bparam and renders" do
          post base_url, params: {b_param: {owner_email: "something@stuff.com", propulsion_type_motorized: "false"}, simple_header: true}
          expect_render_without_xframe
          expect(response).to render_template(:create)
          b_param = BParam.last
          expect(b_param.owner_email).to eq "something@stuff.com"
          expect(b_param.origin).to eq "embed_partial"
          expect(b_param.partial_registration?).to be_truthy
          expect(b_param.motorized?).to be_falsey
          expect(b_param.params["propulsion_type_motorized"]).to be_blank
          expect(Email::PartialRegistrationJob).to have_enqueued_sidekiq_job(b_param.id)
          expect(assigns(:simple_header)).to be_truthy
        end
      end
      context "all values set" do
        let(:attrs) do
          {
            manufacturer_id: manufacturer.id,
            primary_frame_color_id: color.id,
            secondary_frame_color_id: color.id,
            cycle_type: "cargo-rear",
            tertiary_frame_color_id: 222,
            owner_email: "ks78xxxxxx@stuff.com",
            creation_organization_id: 21
          }
        end
        it "creates a new bparam and renders" do
          post base_url, params: {b_param: attrs, propulsion_type_motorized: "true"}
          expect_render_without_xframe
          expect(response).to render_template(:create)
          b_param = BParam.last
          expect(attrs).to have_attributes b_param
          expect(b_param.origin).to eq "embed_partial"
          expect(b_param.motorized?).to be_truthy
          expect(Email::PartialRegistrationJob).to have_enqueued_sidekiq_job(b_param.id)
          expect(b_param.partial_registration?).to be_truthy
        end

        context "with invalid cycle_type" do
          it "creates a new bparam and renders" do
            post base_url, params: {b_param: attrs.merge(cycle_type: "fake cycle type"),
                                    propulsion_type_motorized: "true"}
            expect_render_without_xframe
            expect(response).to render_template(:create)
            b_param = BParam.last
            expect(attrs.except(:cycle_type)).to have_attributes b_param
            expect(b_param.origin).to eq "embed_partial"
            expect(b_param.cycle_type).to eq "bike"
            expect(b_param.motorized?).to be_truthy
            expect(Email::PartialRegistrationJob).to have_enqueued_sidekiq_job(b_param.id)
            expect(b_param.partial_registration?).to be_truthy
          end
        end
      end
    end
  end
end
