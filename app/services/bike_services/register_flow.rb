# frozen_string_literal: true

module BikeServices
  # The register flow's shape. report: :after_details, :last, or nil for a registration
  # with nothing to report
  RegisterFlow = Data.define(:page_count, :report, :single_page) do
    def initialize(page_count: 0, report: nil, single_page: false) = super

    def steps
      details = single_page? ? %w[1] : %w[1 2]
      acknowledgments = page_count.times.map { BikeServices::Register.step_for_page_index(it) } +
        (acknowledgments? ? %w[review] : [])
      case report
      when :after_details then details + %w[report] + acknowledgments
      when :last then details + acknowledgments + %w[report]
      else details + acknowledgments
      end
    end

    def single_page? = single_page

    # The e-vehicle acknowledgment pages, which end at the review
    def acknowledgments? = page_count.positive?

    # 1-based, what the progress bar fills to
    def position(step) = steps.index(step.to_s).to_i + 1

    # What the next and back links go to - nil for the steps nothing comes before or after
    def after(step) = steps[position(step)]

    def before(step)
      steps[position(step) - 2] if position(step) > 1
    end
  end
end
