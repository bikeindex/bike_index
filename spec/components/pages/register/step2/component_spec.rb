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
        expect(organization_target("statusField")["data-organization-off"]).to be_blank
        expect(organization_target("label").text).to match(/information for/i)
      end

      context "dropped" do
        let(:params) { {bike: {owner_email: "owner@bikeindex.org", manufacturer_id: 12}, auto_organization_id: organization.id} }

        it "offers it unchecked, with what it asks for collapsed rather than gone" do
          render_step_2
          expect(page).to have_unchecked_field("register_with_organization")
          expect(page).to have_field("bike[student_id]")
          expect(organization_target("field")[:class]).to include "tw:hidden"
          expect(organization_target("statusField")["data-organization-off"]).to eq "true"

          label = organization_target("label")
          expect(label.text).to match(/contact info/i)
          expect(JSON.parse(label["data-texts"])["on"]).to match(/information for/i)
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
