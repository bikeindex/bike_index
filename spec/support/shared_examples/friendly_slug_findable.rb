require "rails_helper"

RSpec.shared_examples "friendly_slug_findable" do
  let(:model_sym) { subject.class.name.underscore.to_sym }
  let(:instance) { FactoryBot.create model_sym }

  describe "sets slug" do
    let(:instance) { FactoryBot.create(model_sym, name:) }
    let(:name) { "Some Cool NAMe " }
    it "assigns slug on create" do
      expect(instance.reload.name).to eq "Some Cool NAMe"
      expect(instance.slug).to eq "some-cool-name"
    end

    context "with parens" do
      let(:name) { "Some Cool NAMe (additional info)" }
      it "assigns slug without parens" do
        expect(instance.reload.name).to eq name
        expect(instance.slug).to eq "some-cool-name"
      end
    end
  end

  describe "to_param" do
    it "returns slug" do
      subject.slug = "cool slug name"
      expect(subject.to_param).to eq "cool slug name"
    end
  end

  describe "friendly_find" do
    before do
      expect(instance).to be_present
    end

    context "integer_slug" do
      it "finds by id" do
        expect(subject.class.friendly_find(instance.id.to_s)).to eq instance
      end
    end

    context "non-integer slug" do
      it "finds by the slug" do
        expect(subject.class.friendly_find(" #{instance.name}")).to eq instance
        expect(subject.class.friendly_find!(" #{instance.name}")).to eq instance
        expect(subject.class.friendly_find_id(" #{instance.name}")).to eq instance.id
      end
    end
  end
end
