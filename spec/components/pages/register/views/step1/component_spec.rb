# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pages::Register::Views::Step1::Component, type: :component do
  let(:organization) { FactoryBot.create(:organization, short_name: "Brakebills") }
  let(:params) { {bike: {owner_email: "owner@bikeindex.org", creation_organization_id: organization.id}} }
  let(:b_param) { BParam.create(origin: "register_flow", params: params.as_json) }

  # Reloaded, so an organization updated mid-example isn't answered from the copy
  # the previous render left on the registration
  def render_step_1
    reloaded = b_param.reload
    render_inline(described_class.new(b_param: reloaded, flow: BikeServices::Register.flow(reloaded, sequence: nil)))
  end

  # Minus the required "*" the label carries
  def email_label
    page.find("label[for='b_param_owner_email']").text.delete("*").strip
  end

  def email_placeholder
    page.find("input[name='b_param[owner_email]']")["placeholder"]
  end

  describe "the email label and placeholder" do
    it "take the organization's, and fall back to the generic word and example address" do
      render_step_1
      expect(email_label).to eq "Email"
      expect(email_placeholder).to eq "you@example.com"

      # A school has a name worth asking by, without anyone setting one
      organization.update(kind: "school")
      render_step_1
      expect(email_label).to eq "Brakebills email"

      # The admin label wins over the school's name, and names the field rather
      # than the address inside it
      organization.update(registration_field_labels: {owner_email: "brakebills.edu email"})
      render_step_1
      expect(email_label).to eq "brakebills.edu email"
      expect(email_placeholder).to eq "you@example.com"

      organization.update(registration_field_labels: {owner_email: "brakebills.edu email",
                                                      email_placeholder: "you@brakebills.edu"})
      render_step_1
      expect(email_placeholder).to eq "you@brakebills.edu"
      expect(email_label).to eq "brakebills.edu email"
    end

    it "are the generic word and example address without an organization" do
      b_param.update(params: {bike: {owner_email: "owner@bikeindex.org"}}.as_json)
      render_step_1

      expect(email_label).to eq "Email"
      expect(email_placeholder).to eq "you@example.com"
    end
  end

  # Outside the form they submit nothing, which the specs posting `additional` directly
  # can't see. What the field itself has to be is UI::Forms::Honeypot's own spec
  it "renders the honeypot and the submit inside the form" do
    render_step_1

    expect(page).to have_css("form input[name='additional']", visible: :all)
    expect(page).to have_css("form button[type=submit]", text: "Next")
    expect(page).to have_text "Just the essentials to start."
    expect(page).to have_no_css("form [name='bike[serial_number]'], input[name=single_page]", visible: :all)
  end

  context "single_page" do
    let(:component) do
      render_inline(described_class.new(b_param:, current_user: nil,
        flow: BikeServices::Register.flow(b_param, sequence: nil, single_page: true)))
    end

    def field_names(scope)
      component.css("form [name^='#{scope}[']").map { |el| el["name"] }.uniq
    end

    it "posts both steps from one form, each in the scope create reads it from" do
      expect(component).to have_css("form[action='/register'][method=post]")
      expect(field_names("b_param")).to include("b_param[manufacturer_id]", "b_param[owner_email]")
      expect(field_names("bike")).to include("bike[serial_number]", "bike[status]")

      # What tells create the submission carries step 2 as well
      expect(component.css("input[name=single_page]").count).to eq 1
      # The photo's fields_for is bare, so the form has to ask for multipart itself
      expect(component.at_css("form[action='/register']")["enctype"]).to eq "multipart/form-data"
      # One honeypot, not one per step
      expect(component.css("input[name=additional]").count).to eq 1
      expect(component.to_html).to_not include "Just the essentials"
    end

    context "signed in" do
      let(:component) do
        render_inline(described_class.new(b_param:, current_user:,
          flow: BikeServices::Register.flow(b_param, sequence: nil, single_page: true)))
      end
      let(:current_user) { FactoryBot.create(:user_confirmed, email: "owner@bikeindex.org") }
      let(:own_emails) { JSON.parse(component.at_css("[data-controller='register--owner-name']")["data-register--owner-name-own-emails-value"]) }

      it "collapses the name for their own address" do
        expect(own_emails).to include "owner@bikeindex.org"
      end

      context "whose account has no name" do
        let(:current_user) { FactoryBot.create(:user_confirmed, email: "owner@bikeindex.org", name: nil) }

        it "asks for it for their own address too" do
          expect(own_emails).to eq []
        end
      end
    end

    # A failed e-vehicle submission re-renders with its sequence resolved, and the electric
    # checkbox, not the server, is what says the safety pages come next
    context "re-rendered with the safety pages resolved" do
      let(:component) do
        render_inline(described_class.new(b_param:, flow: BikeServices::RegisterFlow.new(single_page: true, page_count: 2)))
      end

      it "still completes the registration for a status with nothing after it" do
        texts = JSON.parse(component.at_css("[data-register--status-fields-target=submitLabel]")["data-texts"])
        expect(texts["status_with_owner"]).to start_with "Complete"
        expect(texts["status_stolen"]).to eq "Next"
      end
    end
  end
end
