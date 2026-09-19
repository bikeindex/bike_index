# frozen_string_literal: true

require "rails_helper"

RSpec.describe ApplicationComponent, type: :component do
  describe "sidecar translations" do
    # MarkupDigest globs a component's own directory, so a sidecar one level up contributes
    # to no digest and its copy can go stale inside a fragment cache — silently, since the
    # digest spec recomputes through that same glob
    it "keeps every sidecar in a directory with the component that reads it" do
      orphaned = Rails.root.glob("app/components/**/component.*.yml")
        .reject { |file| file.dirname.join("component.rb").exist? }
        .map { |file| file.relative_path_from(Rails.root).to_s }

      expect(orphaned).to eq []
    end
  end
end
