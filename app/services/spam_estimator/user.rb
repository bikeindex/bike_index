module SpamEstimator
  module User
    extend Functionable

    MARK_SPAM_PERCENT = 90 # May modify in the future!

    # crypto, gambling, adult and gift-card terms that SEO-spam profiles exist to promote.
    # Word boundaries matter: usernames are auto-generated random strings, so
    # unanchored substrings ("Judith", "Hagen", "Sloth", "Donohue") would ban real people.
    SEO_SPAM_REGEX = /(?:
      \b(?:
        bitcoin | btc | ethereum | crypto(?:currency|\s?wallet)? | blockchain | binance |
        coinbase | dogecoin | altcoin | memecoin | defi | web3 | metamask | airdrop |
        presale | usdt | tether |
        casino | kasino | gambling | roulette | blackjack | baccarat | poker | sportsbook |
        jackpot | judi | togel | toto | situs | gacor | bandar | slot | agen | maxwin |
        terpercaya | taruhan | alternatif | gampang | pragmatic\s+play | scatter\s+hitam |
        rtp | bet365 | betting | wager |
        bokep | hentai | xvideo | (?:phim|clip|truyen)\s?sex |
        nha\s+cai | ca\s+cuoc | da\s+ga | soi\s+keo | no\s+hu | xoc\s+dia |
        nap\s+tien | dang\s+nhap | truc\s+tuyen | khuyen\s+mai | uy\s+tin |
        game\s+bai | co\s+bac | song\s+bac | xo\s+so | lo\s+de |
        link\s+truy\s+cap | clip\s+(?:hot|nong)
      )\b | 18\+ |
      # Gift-card "check your balance" farms run the brand together in usernames and
      # domains (mcgiftgiftcardmall3, vanillaprepaid.io), so these can't be \b-anchored.
      gift\s?(?:cards?|code) | prepaid |
      (?:mc|my|wm|walmart|five\s?back|vanilla|visa|amex|master(?:card)?)-?\s?e?-?gift |
      (?:one|my)-?\s?vanilla | vanilla-?\s?balance | secure-?\s?spend |
      (?:card|gift)\s?balance | balance\s?(?:check|inquiry|inquiries) |
      check\s?(?:my|your|the)?\s?balance | reward\s?cards? |
      card\s?activation | activate\s+(?:my\s|your\s|the\s)?(?:gift\s?)?card |
      redeem\s+(?:code|card)
    )/xi

    def estimate(user)
      return 0 if user.blank?

      # each crypto/gambling reference is a strong signal, stacked onto the text score
      score = spammy_text_estimate(user) + 30 * seo_spam_reference_count(user) +
        promotional_link_estimate(user)

      (score - bike_ownership_reduction(user)).clamp(0, 100)
    end

    # matched terms and their counts, recorded on the ban so false positives are auditable.
    # Vietnamese spam appears both with and without diacritics, so strip them first —
    # I18n.transliterate can't (it renders Vietnamese vowels as "?")
    def seo_spam_matches(user)
      return {} if user.blank?

      strip_diacritics(scannable_strings(user).join(" ")).scan(SEO_SPAM_REGEX)
        .map { |term| term.downcase.gsub(/\s+/, " ") }.tally
    end

    #
    # private below here
    #

    # counts references anywhere in the public profile, including link URLs and handles
    def seo_spam_reference_count(user)
      seo_spam_matches(user).values.sum
    end

    def strip_diacritics(str)
      str.unicode_normalize(:nfd).gsub(/\p{Mn}/, "").tr("đĐ", "dD")
    end

    # description and title are the SEO-spam payload; weight them far above name/username
    # (URLs/handles are only regex-scanned above — the estimator scores them as gibberish)
    def spammy_text_estimate(user)
      heavy = Text.estimate([user.description, user.title].select(&:present?).join(" "))
      light = Text.estimate([user.name, user.username].select(&:present?).join(" "))

      heavy + 0.2 * light
    end

    def scannable_strings(user)
      [user.name, user.title, user.description, user.username, user.mb_link_title,
        user.mb_link_target, user.twitter, user.instagram].select(&:present?)
    end

    # SEO farms exist to host the link — registering bikes is what separates them from riders,
    # so ownership below more than cancels this out
    def promotional_link_estimate(user)
      user.mb_link_target.present? ? 50 : 0
    end

    # real registrations are strong evidence against spam — but only real ones,
    # otherwise a junk registration buys the reduction that cancels the link above
    def bike_ownership_reduction(user)
      case user.bikes.not_spam.limit(2).count
      when 0 then 0
      when 1 then 40
      else 80
      end
    end

    conceal :seo_spam_reference_count, :strip_diacritics, :spammy_text_estimate,
      :scannable_strings, :promotional_link_estimate, :bike_ownership_reduction
  end
end
