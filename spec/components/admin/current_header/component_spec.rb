# frozen_string_literal: true

require "rails_helper"

RSpec.describe Admin::CurrentHeader::Component, type: :component do
  let(:instance) { described_class.new(**options) }
  let(:options) { {params:} }
  let(:params) { {} }

  describe "header presence detection" do
    context "without header params" do
      it "does not render header" do
        expect(instance.send(:header_present?)).to be false
      end
    end

    context "with user_id param" do
      let(:params) { {user_id: 123} }

      it "detects header should be present" do
        expect(instance.send(:header_present?)).to be true
      end
    end

    context "with organization_id param" do
      let(:params) { {organization_id: 456} }

      it "detects header should be present" do
        expect(instance.send(:header_present?)).to be true
      end
    end

    context "with search_bike_id param" do
      let(:params) { {search_bike_id: 789} }

      it "detects header should be present" do
        expect(instance.send(:header_present?)).to be true
      end
    end
  end

  describe "viewing text" do
    context "with viewing parameter" do
      let(:params) { {user_id: 123} }
      let(:options) { {params:, viewing: "Test Item"} }

      it "uses custom viewing text" do
        expect(instance.send(:viewing)).to eq("Test Item")
      end
    end

    context "without viewing parameter" do
      it "would use controller name humanized when rendered" do
        # The viewing method calls controller_name which is only available after rendering
        # We can't test this without full controller context
        expect(instance.instance_variable_get(:@viewing)).to be_nil
      end
    end
  end

  describe "kind_humanized" do
    context "with kind_humanized parameter" do
      let(:params) { {search_kind: "test"} }
      let(:options) { {params:, kind_humanized: "Special Kind"} }

      it "uses custom kind_humanized" do
        expect(instance.send(:kind_humanized)).to eq("Special Kind")
      end
    end

    context "without kind_humanized parameter" do
      let(:params) { {search_kind: "bike_shop"} }

      it "humanizes from search_kind param" do
        expect(instance.send(:kind_humanized)).to eq("Bike shop")
      end
    end
  end

  describe "subject lookups" do
    context "with user_id" do
      let(:user) { FactoryBot.create(:user) }
      let(:params) { {user_id: user.id} }
      let(:options) { {params:, user:} }

      it "identifies user should show" do
        expect(instance.send(:show_user?)).to be true
      end

      it "uses provided user" do
        expect(instance.send(:user_subject)).to eq(user)
      end
    end

    context "with missing user_id" do
      let(:params) { {user_id: 99999} }

      it "identifies user should show" do
        expect(instance.send(:show_user?)).to be true
      end

      it "attempts to find user by id" do
        expect(instance.send(:user_subject)).to be_nil
      end
    end
  end

  describe "rendering without routes" do
    context "empty state" do
      let(:component) { render_inline(instance) }

      it "renders blank when no params" do
        expect(component.to_html.strip).to be_blank
      end
    end
  end
end
