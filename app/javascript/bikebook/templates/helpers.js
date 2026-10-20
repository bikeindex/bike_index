import { html } from 'lit-html'
import { join } from 'bikebook/templates/values'

// A missing value, as light as a unit, which twless-strong isn't
export const missing = html`<span class="tw:text-gray-400 tw:dark:text-gray-500">—</span>`

// ApplicationComponentHelper

// SecureRandom's, since crypto.randomUUID is only in secure contexts
export const randomHex = (bytes) => [...crypto.getRandomValues(new Uint8Array(bytes))].map((byte) => byte.toString(16).padStart(2, '0')).join('')
export const uuid = () => [4, 2, 2, 2, 6].map(randomHex).join('-')

// number_with_delimiter, which leaves the fraction as Ruby prints it
export const numberDisplay = (number) => {
  const [whole, fraction] = String(number).split('.')
  return html`<span class=${number === 0 ? 'less-less-strong' : ''}>${whole.replace(/\B(?=(\d{3})+(?!\d))/g, ',')}${fraction ? `.${fraction}` : ''}</span>`
}

// amount_display(Money.new(cents, code))
export const amountDisplay = (cents, code, currencies) => {
  const currencyCode = code || 'USD'
  const currency = currencies[currencyCode] ?? {}
  return html`<span>${join([html`<span title=${currency.name ?? currencyCode}>${currency.symbol ?? `${currencyCode} `}</span>`, numberDisplay(cents / 100)])}</span>`
}
