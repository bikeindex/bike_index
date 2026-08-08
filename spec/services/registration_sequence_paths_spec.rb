require "rails_helper"

RSpec.describe RegistrationSequencePaths do
  let(:organization) { FactoryBot.create(:organization) }
  let(:registration_sequence) { FactoryBot.create(:registration_sequence, organization:) }
  let(:registration_sequence_page) { FactoryBot.create(:registration_sequence_page, registration_sequence:) }

  context "an organization's sequence" do
    let(:instance) { described_class.new }
    let(:base_url) { "/o/#{organization.to_param}" }

    it "builds the organization's routes" do
      expect(instance.index(registration_sequence)).to eq "#{base_url}/registration_sequences"
      expect(instance.sequence(registration_sequence)).to eq "#{base_url}/registration_sequences/#{registration_sequence.id}"
      expect(instance.sequence(registration_sequence, page: 2)).to eq "#{base_url}/registration_sequences/#{registration_sequence.id}?page=2"
      expect(instance.edit(registration_sequence)).to eq "#{base_url}/registration_sequences/#{registration_sequence.id}/edit"
      expect(instance.new_page(registration_sequence)).to eq "#{base_url}/registration_sequences/#{registration_sequence.id}/pages/new"
      expect(instance.pages(registration_sequence)).to eq "#{base_url}/registration_sequences/#{registration_sequence.id}/pages"
      expect(instance.page(registration_sequence_page)).to eq "#{base_url}/registration_sequence_pages/#{registration_sequence_page.id}"
      expect(instance.edit_page(registration_sequence_page)).to eq "#{base_url}/registration_sequence_pages/#{registration_sequence_page.id}/edit"
    end
  end

  context "admin" do
    let(:instance) { described_class.new(admin: true) }
    let(:registration_sequence) { FactoryBot.create(:registration_sequence_template) }

    it "builds the admin routes, which don't scope to an organization" do
      expect(instance.index(registration_sequence)).to eq "/admin/registration_sequences"
      expect(instance.sequence(registration_sequence)).to eq "/admin/registration_sequences/#{registration_sequence.id}"
      expect(instance.sequence(registration_sequence, page: 2)).to eq "/admin/registration_sequences/#{registration_sequence.id}?page=2"
      expect(instance.edit(registration_sequence)).to eq "/admin/registration_sequences/#{registration_sequence.id}/edit"
      expect(instance.new_page(registration_sequence)).to eq "/admin/registration_sequences/#{registration_sequence.id}/pages/new"
      expect(instance.pages(registration_sequence)).to eq "/admin/registration_sequences/#{registration_sequence.id}/pages"
      expect(instance.page(registration_sequence_page)).to eq "/admin/registration_sequence_pages/#{registration_sequence_page.id}"
      expect(instance.edit_page(registration_sequence_page)).to eq "/admin/registration_sequence_pages/#{registration_sequence_page.id}/edit"
    end
  end

  describe "preview_exit" do
    it "returns to the editor" do
      expect(described_class.new.preview_exit(registration_sequence))
        .to eq "/o/#{organization.to_param}/registration_sequences/#{registration_sequence.id}/edit"
    end

    context "activated sequence" do
      let(:registration_sequence) { FactoryBot.create(:registration_sequence_active, organization:) }

      it "returns to the list - there's no editor for a frozen sequence" do
        expect(described_class.new.preview_exit(registration_sequence))
          .to eq "/o/#{organization.to_param}/registration_sequences"
        expect(described_class.new(admin: true).preview_exit(registration_sequence))
          .to eq "/admin/registration_sequences"
      end
    end
  end
end
