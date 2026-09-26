# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pages::Register::StartPage::Component, type: :component do
  let(:organization) { FactoryBot.create(:organization, short_name: "Brakebills") }
  let(:params) { {bike: {owner_email: "owner@bikeindex.org", creation_organization_id: organization.id}} }
  let(:b_param) { BParam.create(origin: "register_flow", params: params.as_json) }

  # Reloaded, so an organization updated mid-example isn't answered from the copy
  # the previous render left on the registration
  def render_start_page
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
      render_start_page
      expect(email_label).to eq "Email"
      expect(email_placeholder).to eq "you@example.com"

      # A school has a name worth asking by, without anyone setting one
      organization.update(kind: "school")
      render_start_page
      expect(email_label).to eq "Brakebills email"

      # The admin label wins over the school's name, and names the field rather
      # than the address inside it
      organization.update(registration_field_labels: {owner_email: "brakebills.edu email"})
      render_start_page
      expect(email_label).to eq "brakebills.edu email"
      expect(email_placeholder).to eq "you@example.com"

      organization.update(registration_field_labels: {owner_email: "brakebills.edu email",
                                                      email_placeholder: "you@brakebills.edu"})
      render_start_page
      expect(email_placeholder).to eq "you@brakebills.edu"
      expect(email_label).to eq "brakebills.edu email"
    end

    it "are the generic word and example address without an organization" do
      b_param.update(params: {bike: {owner_email: "owner@bikeindex.org"}}.as_json)
      render_start_page

      expect(email_label).to eq "Email"
      expect(email_placeholder).to eq "you@example.com"
    end
  end

  # Outside the form it submits nothing, which the specs posting `additional` directly
  # can't see. What the field itself has to be is UI::Forms::Honeypot's own spec
  it "renders the honeypot inside the form, and step 1's own fields and submit" do
    render_start_page

    expect(page).to have_css("form input[name='additional']", visible: :all)
    expect(page).to have_text "Just the essentials to start."
    expect(page).to have_css("form button[type=submit]", text: "Next")
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
      # One honeypot, not one per step
      expect(component.css("input[name=additional]").count).to eq 1
      expect(component.to_html).to_not include "Just the essentials"
    end
  end
end
