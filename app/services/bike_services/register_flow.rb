# frozen_string_literal: true

module BikeServices
  # The register flow's shape. report: :after_details, :last, or nil for a registration
  # with nothing to report. steps is built from the rest rather than passed in
  RegisterFlow = Data.define(:page_count, :report, :steps) do
    def initialize(page_count: 0, report: nil)
      acknowledgments = page_count.times.map { BikeServices::Register.step_for_page_index(it) } +
        (page_count.positive? ? %w[review] : [])
      steps = case report
      when :after_details then %w[1 2 report] + acknowledgments
      when :last then %w[1 2] + acknowledgments + %w[report]
      else %w[1 2] + acknowledgments
      end
      super(page_count:, report:, steps: steps.freeze)
    end

    # The e-vehicle acknowledgment pages, which end at the review
    def acknowledgments? = page_count.positive?

    def count = steps.count

    # 1-based, what the progress bar fills to
    def position(step) = steps.index(step.to_s).to_i + 1

    # What the next and back links go to - nil for the steps nothing comes before or after
    def after(step) = steps[position(step)]

    def before(step)
      index = position(step) - 2
      steps[index] unless index.negative?
    end
  end
end
