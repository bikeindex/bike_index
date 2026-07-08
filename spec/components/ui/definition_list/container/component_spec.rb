# frozen_string_literal: true

require "rails_helper"

RSpec.describe UI::DefinitionList::Container::Component, type: :component do
  it "renders each valid term" do
    %i[left_align right_align below].each do |term|
      expect { render_inline(described_class.new(term:)) }.not_to raise_error
    end
  end

  it "raises for an unknown term" do
    expect { described_class.new(term: :center) }.to raise_error(ArgumentError, /term must be one of/)
  end
end
