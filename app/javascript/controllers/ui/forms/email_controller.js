import { Controller } from '@hotwired/stimulus'
import { collapse } from 'utils/collapse_utils'

// Connects to data-controller='ui--forms--email'
// Offers a correction whenever the field is left holding a near-miss of a well known
// email domain, and swaps it in if the suggestion is clicked. A domain no message can
// arrive at gets the warning instead, which there's nothing to correct it to. Either
// one holds the form until it's answered, or the way past it is taken.
export default class extends Controller {
  static targets = ['input', 'suggestion', 'correction', 'warning', 'override']
  static values = { reserved: String }

  // Whether the field has something to say, which is what holds the form back.
  check () {
    const email = this.inputTarget.value
    // The domain's, the way the server's is -- SpamEstimator::Bike#reserved_email_domain?
    const reserved = new RegExp(this.reservedValue, 'i').test(email.split('@').at(-1).trim())
    this.suggested = reserved ? null : suggest(email)

    // Set before showing: collapse animates to the height the text gives it.
    if (this.suggested) this.correctionTarget.textContent = this.suggested
    collapse(this.suggested ? 'show' : 'hide', this.suggestionTarget)
    collapse(reserved ? 'show' : 'hide', this.warningTarget)

    const held = reserved || Boolean(this.suggested)
    this.hold(held)

    return held
  }

  // Typing answers whatever was asked, so the field goes quiet and hands the form back
  // until the value settles and focusout checks it again.
  clear () {
    collapse('hide', [this.suggestionTarget, this.warningTarget])
    this.hold(false)
  }

  // Enter never leaves the field, so the value is checked here too -- and a message
  // takes the keystroke, since submitting past one is what it's there to ask about.
  // Enter on a button of ours is that button's, which is what answers it.
  checkOnEnter (event) {
    if (event.target !== this.inputTarget) return

    if (this.check()) event.preventDefault()
  }

  accept () {
    this.inputTarget.value = this.suggested
    // Assigning a value fires neither event, and anything watching the field expects both.
    // The input is one of those watchers, so this runs clear() -- check() has to follow it.
    this.inputTarget.dispatchEvent(new Event('input', { bubbles: true }))
    this.inputTarget.dispatchEvent(new Event('change', { bubbles: true }))
    // The correction can be a domain the warning is about, so it's checked like any other.
    this.check()
    // The suggestion is on its way out, so focus can't stay on it.
    this.inputTarget.focus()
  }

  submitAnyway () {
    this.clear()
    this.form?.requestSubmit()
  }

  // The submit belongs to the form rather than to us, so releasing it puts back only
  // what we took -- ui--button--submit-spinner disables the same button to see off a
  // second submit, and a clean focusout has no business undoing that.
  hold (held) {
    collapse(held ? 'show' : 'hide', this.overrideTarget)
    this.holding?.forEach((submit) => { submit.disabled = false })
    this.holding = held ? [...this.submits].filter((submit) => !submit.disabled) : []
    this.holding.forEach((submit) => { submit.disabled = true })
  }

  get form () {
    return this.element.closest('form')
  }

  get submits () {
    return this.form?.querySelectorAll('[type="submit"]') ?? []
  }
}

// The mail providers people mistype the name of.
const NAMES = [
  'gmail', 'googlemail', 'yahoo', 'ymail', 'hotmail', 'outlook', 'live', 'msn', 'aol',
  'icloud', 'me', 'mac', 'protonmail', 'proton', 'gmx', 'mail', 'email', 'yandex', 'zoho',
  'fastmail', 'hey', 'comcast', 'verizon', 'att', 'sbcglobal', 'bellsouth', 'cox', 'charter',
  'earthlink', 'shaw', 'sympatico', 'telus', 'btinternet'
]

// The names above that exist as a ".com" and nothing else, so a near-miss of it is wrong
// however real the ending is elsewhere -- ".co" is Colombia to everyone but Gmail.
const COM_ONLY = [
  'gmail', 'googlemail', 'yahoo', 'ymail', 'hotmail', 'outlook', 'icloud', 'protonmail',
  'aol', 'msn', 'live', 'me', 'mac', 'hey', 'fastmail'
]

// Endings worth knowing. The two-letter ones are never corrected to, only recognized --
// which is what keeps ".co" from being read as ".com" with a letter dropped.
const ENDINGS = [
  'com', 'net', 'org', 'edu', 'gov', 'mil', 'co', 'io', 'me', 'info', 'biz', 'app', 'dev',
  'bike', 'cc', 'tv', 'us', 'ca', 'mx', 'br', 'ar', 'cl', 'eu', 'uk', 'co.uk', 'org.uk',
  'ac.uk', 'ie', 'fr', 'de', 'ch', 'at', 'nl', 'be', 'es', 'pt', 'it', 'se', 'no', 'dk',
  'fi', 'pl', 'cz', 'gr', 'ru', 'ua', 'tr', 'il', 'in', 'jp', 'co.jp', 'cn', 'kr', 'hk',
  'tw', 'sg', 'au', 'com.au', 'nz', 'co.nz', 'za', 'co.za'
]

// The name and the ending are matched apart, the way they're mistyped -- so an ending is
// corrected on a domain nobody here has heard of, and a name we don't know keeps its own.
function suggest (email) {
  const at = email.lastIndexOf('@')
  if (at < 1) return null

  // A dot with nothing on one side of it is a typo of its own, so it goes before matching
  // -- leaving each part a whole typo to spend on itself, which ".gmail..come" needs.
  const typed = email.slice(at + 1).toLowerCase()
  const [name, ...rest] = typed.split('.').filter(Boolean)
  if (!rest.length) return null

  const corrected = closest(name, NAMES, 4)
  const domain = `${corrected}.${ending(corrected, rest.join('.'))}`

  return (domain === typed) ? null : `${email.slice(0, at)}@${domain}`
}

// A name we recognize vouches for its own ending, which is the only way to read ".co" as
// a typo -- on its own it's a country's, and left alone.
function ending (name, typed) {
  if (COM_ONLY.includes(name) && typed !== 'com' && oneTypoApart(typed, 'com')) return 'com'

  return closest(typed, ENDINGS, 3)
}

// The entry a single typo away, or the part itself -- which is every domain we have no
// opinion about, as well as the ones we know. Nothing under three characters is worth
// correcting to, and a part under minLength only when it dropped a letter (".om" -> ".com").
function closest (part, candidates, minLength) {
  if (candidates.includes(part)) return part

  return candidates.find((candidate) => candidate.length > 2 &&
    (part.length >= minLength || candidate.length === part.length + 1) &&
    oneTypoApart(part, candidate)) ?? part
}

// Strip the ends the two share and a single typo is all that can be left: a letter
// dropped, added, mistyped, or swapped with the one beside it ("gmial").
function oneTypoApart (a, b) {
  if (Math.abs(a.length - b.length) > 1) return false

  let start = 0
  while (start < a.length && start < b.length && a[start] === b[start]) start++
  let end = 0
  while (end < a.length - start && end < b.length - start && a.at(-1 - end) === b.at(-1 - end)) end++

  const [restOfA, restOfB] = [a.slice(start, a.length - end), b.slice(start, b.length - end)]

  return (restOfA.length <= 1 && restOfB.length <= 1) ||
    (restOfA.length === 2 && restOfA === [...restOfB].reverse().join(''))
}
