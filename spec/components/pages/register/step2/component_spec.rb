# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pages::Register::Step2::Component, type: :component do
  let(:organization) { FactoryBot.create(:organization) }
  let(:params) do
    {bike: {owner_email: "owner@bikeindex.org", manufacturer_id: 12,
            creation_organization_id: organization.id}}
  end
  let(:b_param) { BParam.create(origin: "register_flow", params: params.as_json) }

  # Reloaded, so an organization updated mid-example isn't answered from the copy
  # the previous render left on the registration
  def render_step_2
    reloaded = b_param.reload
    render_inline(described_class.new(b_param: reloaded,
      steps: BikeServices::Register.steps(reloaded, sequence: nil)))
  end

  # The wrapper register--status-fields shows and requires, rather than the input itself.
  # visible: :all throughout - a field the status doesn't ask for renders collapsed
  def status_field(field_name)
    page.find("[data-register--status-fields-target='field']:has([name^='bike[#{field_name}'])", visible: :all)
  end

  describe "the organization checkbox" do
    # tw:hidden rather than absent, so checking the box again has something to bring back
    def organization_target(name) = page.find("[data-register--organization-target='#{name}']", visible: :all)

    it "isn't offered for an organization a link named" do
      render_step_2
      expect(page).to_not have_field("register_with_organization")
    end

    context "assigned automatically" do
      let(:params) { super().merge(auto_organization_id: organization.id) }
      before { organization.update_column :enabled_feature_slugs, %w[reg_student_id reg_address] }

      it "offers it checked, heading the fields it decides" do
        render_step_2
        expect(page).to have_checked_field("register_with_organization")
        expect(page).to have_field("bike[student_id]")
        expect(organization_target("field")[:class]).to_not include "tw:hidden"
        expect(status_field("address_record_attributes")["data-organization-off"]).to be_blank
        expect(organization_target("label").text).to match(/information for/i)
      end

      context "dropped" do
        let(:params) { {bike: {owner_email: "owner@bikeindex.org", manufacturer_id: 12}, auto_organization_id: organization.id} }

        it "offers it unchecked, with what it asks for collapsed rather than gone" do
          render_step_2
          expect(page).to have_unchecked_field("register_with_organization")
          expect(page).to have_field("bike[student_id]")
          expect(organization_target("field")[:class]).to include "tw:hidden"
          expect(status_field("address_record_attributes")["data-organization-off"]).to eq "true"

          label = organization_target("label")
          expect(label.text).to match(/contact info/i)
          expect(JSON.parse(label["data-texts"])["on"]).to match(/information for/i)
        end
      end
    end
  end

  describe "the phone field" do
    def phone_field = status_field("phone")

    def phone_element(selector) = phone_field.find(selector, visible: :all)

    def phone_texts = JSON.parse(phone_field["data-texts"])

    let(:report_texts) do
      {"status_stolen" => "Phone is required to register a stolen bike",
       "status_impounded" => "Phone is required to register a found bike"}
    end
    let(:org_text) { "Phone is required to register with #{organization.short_name}" }

    # A theft or a find is contacted on it, so those two ask for a phone rather than
    # offering one - and the status that decides which is picked in this form
    it "requires the phone for a theft or a find, saying which" do
      render_step_2
      expect(phone_element("input[name='bike[phone]']")["required"]).to be_blank
      expect(phone_element("[data-optional-marker]")["hidden"]).to be_blank
      expect(phone_element("[data-required-marker]")["hidden"]).to be_present
      expect(phone_element("[data-required-helper]")["hidden"]).to be_present
      expect(phone_texts).to eq report_texts

      b_param.update(params: b_param.params.deep_merge("bike" => {"status" => "status_stolen"}))
      render_step_2
      expect(phone_element("input[name='bike[phone]']")["required"]).to be_present
      expect(phone_element("[data-optional-marker]")["hidden"]).to be_present
      expect(phone_element("[data-required-marker]")["hidden"]).to be_blank
      helper = phone_element("[data-required-helper]")
      expect(helper["hidden"]).to be_blank
      expect(helper.text.strip).to eq "Phone is required to register a stolen bike"
    end

    context "reg_phone" do
      it "only requires the phone when the organization requires it" do
        organization.update_column :enabled_feature_slugs, ["reg_phone"]
        render_step_2
        expect(phone_element("input[name='bike[phone]']")["required"]).to be_blank
        expect(phone_texts).to eq report_texts

        organization.update_column :enabled_feature_slugs, %w[reg_phone require_reg_phone]
        render_step_2
        expect(phone_element("input[name='bike[phone]']")["required"]).to be_present
        # A theft or a find still says which of them is asking
        expect(phone_texts).to eq({"status_with_owner" => org_text, "status_abandoned" => org_text,
                                   "unregistered_parking_notification" => org_text}.merge(report_texts))
        expect(phone_element("[data-required-helper]").text.strip).to eq org_text
      end

      it "doesn't require a phone the organization isn't asking for" do
        organization.update_column :enabled_feature_slugs, ["require_reg_phone"]
        render_step_2
        expect(phone_element("input[name='bike[phone]']")["required"]).to be_blank
        expect(phone_texts).to eq report_texts
      end

      # Unchecking the box takes back what the organization asks for, so the phone goes
      # with it - register--status-fields reads the answers here when the flag is set
      context "with the organization dropped" do
        let(:params) do
          {bike: {owner_email: "owner@bikeindex.org", manufacturer_id: 12}, auto_organization_id: organization.id}
        end
        before { organization.update_column :enabled_feature_slugs, %w[reg_phone require_reg_phone] }

        it "asks the way a registration without the organization does" do
          render_step_2
          expect(phone_field["data-organization-off"]).to eq "true"
          expect(phone_element("input[name='bike[phone]']")["required"]).to be_blank
          expect(phone_element("[data-required-helper]")["hidden"]).to be_present
          expect(phone_field[:class]).to include "tw:hidden"
          expect(JSON.parse(phone_field["data-organization-off-statuses"]))
            .to eq %w[status_stolen status_impounded]
          expect(JSON.parse(phone_field["data-organization-off-texts"])).to eq report_texts
          # Checking it again brings the organization's answers back
          expect(phone_texts).to include("status_with_owner" => org_text)
        end
      end
    end
  end

  describe "the bike sticker field" do
    # reg_bike_sticker rides along with bike_stickers (Organization#enabled_feature_slugs),
    # which update_column skips - so both are set here the way it would leave them
    it "asks for it only for an organization with user editable stickers" do
      render_step_2
      expect(page).to_not have_field("bike[bike_sticker]")

      organization.update_column :enabled_feature_slugs, %w[bike_stickers reg_bike_sticker]
      render_step_2
      expect(page).to_not have_field("bike[bike_sticker]")

      organization.update_column :enabled_feature_slugs,
        %w[bike_stickers reg_bike_sticker bike_stickers_user_editable]
      render_step_2
      expect(page).to have_field("bike[bike_sticker]")
    end

    it "asks for the one a scanned registration already carries" do
      b_param.update(params: b_param.params.deep_merge("bike" => {"bike_sticker" => "A 471 829"}))
      render_step_2

      expect(organization.additional_registration_fields).to_not include "reg_bike_sticker"
      expect(page).to have_field("bike[bike_sticker]", with: "A 471 829")
    end
  end
end
