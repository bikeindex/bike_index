# frozen_string_literal: true

require "i18n/tasks"

RSpec.describe "I18n" do
  let(:i18n) { I18n::Tasks::BaseTask.new }
  let(:missing_keys) { i18n.missing_keys }
  let(:unused_keys) { i18n.unused_keys }

  it "does not have missing keys" do
    error_message = <<~STR
      Missing #{missing_keys.leaves.count} i18n keys.\n
      Run `i18n-tasks missing' to show them
    STR

    expect(missing_keys).to be_empty, error_message
  end

  it "does not have unused keys" do
    error_message = <<~STR
      #{unused_keys.leaves.count} unused i18n keys.\n
      Run `i18n-tasks unused' to show them.
    STR

    expect(unused_keys).to be_empty, error_message
  end

  it "files are normalized" do
    non_normalized = i18n.non_normalized_paths

    error_message = <<~STR
      The following files need to be normalized:
      #{non_normalized.map { |path| "  #{path}" }.join("\n")}\n
      Please run `i18n-tasks` normalize to fix.
    STR

    expect(non_normalized).to be_empty, error_message
  end
end
