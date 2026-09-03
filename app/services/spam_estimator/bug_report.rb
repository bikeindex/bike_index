module SpamEstimator
  module BugReport
    extend Functionable

    MARK_SPAM_PERCENT = 90 # May modify in the future!
    # Email bodies run to tens of KB; the spam signal (HTML markup, link/tracker density) is
    # dense from the first characters, so a sample is representative and bounds the work.
    MAX_SAMPLE_LENGTH = 1000

    def estimate(bug_report)
      return 0 if bug_report.blank?

      body_sample = bug_report.body.to_s.slice(0, MAX_SAMPLE_LENGTH)
      [Text.estimate(bug_report.subject), Text.estimate(body_sample)].max
    end
  end
end
