# frozen_string_literal: true

require "rails_helper"

# The user cell is rendered by two dozen admin tables, and caches itself inside their
# rows: one fragment, read wherever the user appears. Two real tables here, because
# nothing in one table's own spec can show the fragment crossing.
RSpec.describe Atoms::Admin::TableCells::User::Component, type: :request do
  include_context :request_spec_logged_in_as_superuser

  let(:user) { FactoryBot.create(:user_confirmed, email: "shared@example.com") }
  let!(:membership) { FactoryBot.create(:membership, user:, creator: user) }
  let!(:email_ban) { FactoryBot.create(:email_ban, user:) }
  # Creating the ban touches the user, so the key the page writes is the reloaded one
  before { user.reload }

  def user_fragments(keys) = keys.select { it.include?(described_class.cache_digest) }

  context "with caching", :caching do
    include_context :caching_basic

    it "writes one fragment for the user, which the other table's rows read" do
      keys = fragments_written { get "/admin/memberships" }

      # The user and creator columns are the same user, so two cells and one fragment
      expect(user_fragments(keys).count).to eq 1
      expect(user_fragments(keys).first).to include(user.cache_key_with_version, "locale/en")
      expect(response.body).to include("shared@example.com")

      # A different table, so its own rows are cold - the user's fragment is not
      keys = fragments_written { get "/admin/email_bans" }
      expect(keys).to be_present
      expect(user_fragments(keys)).to eq([])
      expect(response.body).to include("shared@example.com")

      # The change busts the user's fragment and the rows keyed on the user; the other
      # table's rows then read the one fragment the first rewrote
      user.update(email: "changed@example.com")
      keys = fragments_written { get "/admin/memberships" }
      expect(user_fragments(keys).count).to eq 1
      expect(user_fragments(keys).first).to include(user.reload.cache_key_with_version)
      expect(response.body).to include("changed@example.com")

      expect(user_fragments(fragments_written { get "/admin/email_bans" })).to eq([])
      expect(response.body).to include("changed@example.com")
    end
  end
end
