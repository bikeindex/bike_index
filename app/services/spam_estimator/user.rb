module SpamEstimator
  module User
    extend Functionable

    MARK_SPAM_PERCENT = 90 # May modify in the future!

    # crypto, gambling and adult terms that SEO-spam profiles exist to promote.
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
      )\b | 18\+
    )/xi

    def estimate(user)
      return 0 if user.blank?

      # each crypto/gambling reference is a strong signal, stacked onto the text score
      score = spammy_text_estimate(user) + 30 * seo_spam_reference_count(user)

      (score - bike_ownership_reduction(user)).clamp(0, 100)
    end

    #
    # private below here
    #

    # count of references anywhere in the public profile, including link URLs and handles.
    # Vietnamese spam appears both with and without diacritics, so strip them first —
    # I18n.transliterate can't (it renders Vietnamese vowels as "?")
    def seo_spam_reference_count(user)
      strip_diacritics(scannable_strings(user).join(" ")).scan(SEO_SPAM_REGEX).count
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

    # real registrations are strong evidence against spam
    def bike_ownership_reduction(user)
      case user.bikes.limit(2).count
      when 0 then 0
      when 1 then 30
      else 50
      end
    end

    conceal :seo_spam_reference_count, :strip_diacritics, :spammy_text_estimate,
      :scannable_strings, :bike_ownership_reduction
  end
end
