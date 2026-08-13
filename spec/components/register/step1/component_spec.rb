# frozen_string_literal: true

require "rails_helper"

RSpec.describe Register::Step1::Component, type: :component do
  let(:organization) { FactoryBot.create(:organization, short_name: "Brakebills") }
  let(:params) { {bike: {owner_email: "owner@bikeindex.org", creation_organization_id: organization.id}} }
  let(:b_param) { BParam.create(origin: "register_flow", params: params.as_json) }

  # Reloaded, so an organization updated mid-example isn't answered from the copy
  # the previous render left on the registration
  def render_step_1
    reloaded = b_param.reload
    render_inline(described_class.new(b_param: reloaded,
      steps: BikeServices::Register.steps(reloaded, sequence: nil)))
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
end
