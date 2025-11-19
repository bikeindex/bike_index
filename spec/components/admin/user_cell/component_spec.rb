# frozen_string_literal: true

require "rails_helper"

RSpec.describe Admin::UserCell::Component, type: :component do
  let(:instance) { described_class.new(**options) }
  let(:options) { {} }

  describe "initialization with defaults" do
    context "with user object" do
      let(:user) { FactoryBot.create(:user, email: "test@example.com") }
      let(:options) { {user:} }

      it "extracts user_id and email from user" do
        expect(instance.instance_variable_get(:@user_id)).to eq(user.id)
        expect(instance.instance_variable_get(:@email)).to eq("test@example.com")
      end
    end

    context "with explicit values" do
      let(:options) { {user_id: 123, email: "explicit@example.com"} }

      it "uses provided values" do
        expect(instance.instance_variable_get(:@user_id)).to eq(123)
        expect(instance.instance_variable_get(:@email)).to eq("explicit@example.com")
      end
    end
  end

  describe "#show_missing_user?" do
    context "with user_id but no user" do
      let(:options) { {user_id: 999} }

      it "returns true" do
        expect(instance.send(:show_missing_user?)).to be true
      end
    end

    context "with user present" do
      let(:user) { FactoryBot.create(:user) }
      let(:options) { {user:} }

      it "returns false" do
        expect(instance.send(:show_missing_user?)).to be false
      end
    end
  end

  describe "#show_user_link?" do
    context "with user present" do
      let(:user) { FactoryBot.create(:user) }
      let(:options) { {user:} }

      it "returns true" do
        expect(instance.send(:show_user_link?)).to be true
      end
    end

    context "without user" do
      let(:options) { {email: "test@example.com"} }

      it "returns false" do
        expect(instance.send(:show_user_link?)).to be false
      end
    end
  end

  describe "#show_email_only?" do
    context "with email but no user" do
      let(:options) { {email: "orphaned@example.com"} }

      it "returns true" do
        expect(instance.send(:show_email_only?)).to be true
      end
    end

    context "with user and email" do
      let(:user) { FactoryBot.create(:user) }
      let(:options) { {user:} }

      it "returns false" do
        expect(instance.send(:show_email_only?)).to be false
      end
    end
  end

  describe "#show_search?" do
    context "with render_search true and email" do
      let(:options) { {email: "test@example.com", render_search: true} }

      it "returns true" do
        expect(instance.send(:show_search?)).to be true
      end
    end

    context "with render_search false" do
      let(:options) { {email: "test@example.com", render_search: false} }

      it "returns false" do
        expect(instance.send(:show_search?)).to be false
      end
    end

    context "without email or user_id" do
      let(:options) { {render_search: true} }

      it "returns false" do
        expect(instance.send(:show_search?)).to be false
      end
    end
  end

  describe "#email_display" do
    context "with short email" do
      let(:options) { {email: "short@example.com"} }

      it "returns full email" do
        expect(instance.send(:email_display)).to eq("short@example.com")
      end
    end

    context "with long email" do
      let(:long_email) { "very.long.email.address.that.exceeds.thirty.characters@example.com" }
      let(:options) { {email: long_email} }

      it "truncates to 30 characters" do
        expect(instance.send(:email_display).length).to eq(30)
        expect(instance.send(:email_display)).to end_with("...")
      end
    end
  end
end
