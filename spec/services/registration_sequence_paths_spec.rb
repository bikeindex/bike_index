require "rails_helper"

RSpec.describe RegistrationSequencePaths do
  let(:organization) { FactoryBot.create(:organization) }
  let(:registration_sequence) { FactoryBot.create(:registration_sequence, organization:) }
  let(:registration_sequence_page) { FactoryBot.create(:registration_sequence_page, registration_sequence:) }

  context "an organization's sequence" do
    let(:base_url) { "/o/#{organization.to_param}" }

    it "builds the organization's routes" do
      expect(described_class.index(registration_sequence)).to eq "#{base_url}/registration_sequences"
      expect(described_class.sequence(registration_sequence)).to eq "#{base_url}/registration_sequences/#{registration_sequence.id}"
      expect(described_class.sequence(registration_sequence, page: 2)).to eq "#{base_url}/registration_sequences/#{registration_sequence.id}?page=2"
      # The organization's member path is its preview; admin's is a screen of its own
      expect(described_class.preview(registration_sequence)).to eq "#{base_url}/registration_sequences/#{registration_sequence.id}"
      expect(described_class.edit(registration_sequence)).to eq "#{base_url}/registration_sequences/#{registration_sequence.id}/edit"
      expect(described_class.new_page(registration_sequence)).to eq "#{base_url}/registration_sequences/#{registration_sequence.id}/pages/new"
      expect(described_class.pages(registration_sequence)).to eq "#{base_url}/registration_sequences/#{registration_sequence.id}/pages"
      expect(described_class.page(registration_sequence_page)).to eq "#{base_url}/registration_sequence_pages/#{registration_sequence_page.id}"
      expect(described_class.edit_page(registration_sequence_page)).to eq "#{base_url}/registration_sequence_pages/#{registration_sequence_page.id}/edit"
    end
  end

  context "admin" do
    let(:registration_sequence) { FactoryBot.create(:registration_sequence_template) }

    it "builds the admin routes, which don't scope to an organization" do
      expect(described_class.index(registration_sequence, admin: true)).to eq "/admin/registration_sequences"
      expect(described_class.sequence(registration_sequence, admin: true)).to eq "/admin/registration_sequences/#{registration_sequence.id}"
      expect(described_class.sequence(registration_sequence, page: 2, admin: true)).to eq "/admin/registration_sequences/#{registration_sequence.id}?page=2"
      expect(described_class.preview(registration_sequence, admin: true)).to eq "/admin/registration_sequences/#{registration_sequence.id}/preview"
      expect(described_class.preview(registration_sequence, page: 2, admin: true)).to eq "/admin/registration_sequences/#{registration_sequence.id}/preview?page=2"
      expect(described_class.edit(registration_sequence, admin: true)).to eq "/admin/registration_sequences/#{registration_sequence.id}/edit"
      expect(described_class.new_page(registration_sequence, admin: true)).to eq "/admin/registration_sequences/#{registration_sequence.id}/pages/new"
      expect(described_class.pages(registration_sequence, admin: true)).to eq "/admin/registration_sequences/#{registration_sequence.id}/pages"
      expect(described_class.page(registration_sequence_page, admin: true)).to eq "/admin/registration_sequence_pages/#{registration_sequence_page.id}"
      expect(described_class.edit_page(registration_sequence_page, admin: true)).to eq "/admin/registration_sequence_pages/#{registration_sequence_page.id}/edit"
    end
  end

  describe "preview_exit" do
    it "returns admin to the read-only screen, which every sequence has" do
      expect(described_class.preview_exit(registration_sequence, admin: true))
        .to eq "/admin/registration_sequences/#{registration_sequence.id}"
    end

    it "returns to the editor" do
      expect(described_class.preview_exit(registration_sequence))
        .to eq "/o/#{organization.to_param}/registration_sequences/#{registration_sequence.id}/edit"
    end

    context "activated sequence" do
      let(:registration_sequence) { FactoryBot.create(:registration_sequence_active, organization:) }

      it "returns to the organization's list - it has no editor for a frozen sequence" do
        expect(described_class.preview_exit(registration_sequence))
          .to eq "/o/#{organization.to_param}/registration_sequences"
      end
    end
  end
end
