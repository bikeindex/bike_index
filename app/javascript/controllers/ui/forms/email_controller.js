import { Controller } from '@hotwired/stimulus'
import { collapse } from 'utils/collapse_utils'

// Connects to data-controller='ui--forms--email'
// Offers a correction whenever the field is left holding a near-miss of a well known
// email domain, and swaps it in if the suggestion is clicked.
export default class extends Controller {
  static targets = ['input', 'suggestion']
  static values = { message: String }

  check () {
    this.suggested = suggest(this.inputTarget.value)
    if (!this.suggested) return collapse('hide', this.suggestionTarget)

    // Before showing: collapse animates to the height the text gives it.
    this.suggestionTarget.textContent = this.messageValue.replace('%{email}', this.suggested)
    collapse('show', this.suggestionTarget)
  }

  accept () {
    this.inputTarget.value = this.suggested
    collapse('hide', this.suggestionTarget)
    // Assigning a value fires neither event, and anything watching the field expects both.
    this.inputTarget.dispatchEvent(new Event('input', { bubbles: true }))
    this.inputTarget.dispatchEvent(new Event('change', { bubbles: true }))
    // The suggestion is on its way out, so focus can't stay on it.
    this.inputTarget.focus()
  }
}

// The mail providers people mistype the name of.
const NAMES = [
  'gmail', 'googlemail', 'yahoo', 'ymail', 'hotmail', 'outlook', 'live', 'msn', 'aol',
  'icloud', 'me', 'mac', 'protonmail', 'proton', 'gmx', 'mail', 'email', 'yandex', 'zoho',
  'fastmail', 'hey', 'comcast', 'verizon', 'att', 'sbcglobal', 'bellsouth', 'cox', 'charter',
  'earthlink', 'shaw', 'sympatico', 'telus', 'btinternet'
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

  const domain = `${closest(name, NAMES, 4)}.${closest(rest.join('.'), ENDINGS, 3)}`

  return (domain === typed) ? null : `${email.slice(0, at)}@${domain}`
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
