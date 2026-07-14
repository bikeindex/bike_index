module SeoSpaminess
  extend Functionable

  MARK_SPAM_PERCENT = SpamEstimator::MARK_SPAM_PERCENT

  # crypto and gambling terms that SEO-spam profiles exist to promote
  SEO_SPAM_REGEX = /\b(?:
    bitcoin | btc | ethereum | crypto(?:currency|\s?wallet)? | blockchain | binance |
    coinbase | dogecoin | altcoin | memecoin | defi | web3 | metamask | airdrop |
    presale | usdt | tether |
    casino | gambling | roulette | blackjack | baccarat | poker | sportsbook |
    jackpot | judi | togel | situs | gacor | bandar | slot\s?(?:gacor|online|88) |
    bet365 | betting | wager
  )\b/xi

  def estimate_user(user)
    return 0 if user.blank?
    # a crypto/gambling reference anywhere in the profile is a definite signal
    return 100 if seo_spam_references?(user)

    spammy_text_estimate(user)
  end

  #
  # private below here
  #

  # references anywhere in the public profile, including link URLs and handles
  def seo_spam_references?(user)
    scannable_strings(user).any? { |str| str.match?(SEO_SPAM_REGEX) }
  end

  # the existing estimator, run over free-text fields only (URLs/handles score as
  # gibberish and would false-positive)
  def spammy_text_estimate(user)
    text = [user.name, user.title, user.description].select(&:present?).join(" ")
    return 0 if text.blank?

    SpamEstimator.string_spaminess(text)
  end

  def scannable_strings(user)
    [user.name, user.title, user.description, user.username, user.mb_link_title,
      user.mb_link_target, user.twitter, user.instagram].select(&:present?)
  end

  conceal :seo_spam_references?, :spammy_text_estimate, :scannable_strings
end
