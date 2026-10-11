import { Controller } from '@hotwired/stimulus'
import { collapse } from 'utils/collapse_utils'

// A week, as form-persist keeps the draft whose step this is
const STEP_TTL_MS = 7 * 24 * 60 * 60 * 1000

// Connects to data-controller='stolen-report--wizard'
// Every step of the report is on the page; this shows one at a time. Moving on checks only what the
// current step requires, the rail and the review say what each step holds, and submitting jumps back
// to the first step still missing something required. Each step is a history entry, so the browser's
// back button goes back a step
export default class extends Controller {
  static targets = [
    'panel', 'railItem', 'railMarker', 'railNote', 'progressSegment', 'progressLabel', 'summary', 'summaryLink',
    'backButton', 'skipButton', 'continueButton', 'submitButton', 'timezone', 'date', 'time',
    'photoAdded', 'stockPhotos', 'stockPhotosFrame', 'stockManufacturer', 'stockModel', 'stockYear',
    'estimatedValue', 'valueUnknown', 'mobileStep'
  ]

  static values = {
    step: String,
    steps: Array,
    optional: Array,
    // The register flow's steps, numbered ahead of these when it handed off here
    offset: Number,
    visited: Array,
    text: Object,
    stockPhotosUrl: String,
    // Editing a saved report, which saves from any step rather than only the review
    editing: Boolean,
    // Where a new report's step is kept, so reopening its draft goes back to it
    draftKey: String,
    currency: String
  }

  connect () {
    this.timezoneTarget.value = Intl.DateTimeFormat().resolvedOptions().timeZone
    this.localizeDateStolen()
    this.visited = new Set(this.visitedValue)
    this.show(this.resumedStep() || this.stepValue)
    // The entry the page loaded on says which step it shows, so going back to it lands there
    const url = new URL(window.location.href)
    url.searchParams.set('step', this.stepValue)
    window.history.replaceState(window.history.state, '', url)
  }

  next () {
    if (!this.validate(this.currentPanel)) return

    this.navigate(this.stepAt(1))
  }

  skip () {
    this.navigate(this.stepAt(1))
  }

  back () {
    this.navigate(this.stepAt(-1))
  }

  goto ({ params: { step } }) {
    this.navigate(step)
  }

  // Enter in a field would submit the whole report from wherever it is - it moves on instead,
  // or searches, in the search's own fields
  enter (event) {
    const field = event.target
    if (field.tagName === 'TEXTAREA' || field.tagName === 'BUTTON' || field.getAttribute('role') === 'combobox') return

    event.preventDefault()
    if ([this.stockManufacturerTarget, this.stockModelTarget, this.stockYearTarget].includes(field)) return this.searchStockPhotos()
    if (this.stepValue !== 'review') this.next()
  }

  restoreStep () {
    const step = new URL(window.location.href).searchParams.get('step') || this.stepsValue[0]
    if (this.stepsValue.includes(step) && step !== this.stepValue) this.show(step, { focus: true })
  }

  submit (event) {
    const invalidStep = this.stepsValue.find((step) => !this.validate(this.panelFor(step), false))
    if (!invalidStep) return this.forgetStep()

    event.preventDefault()
    event.stopImmediatePropagation()
    this.navigate(invalidStep)
    this.validate(this.currentPanel)
  }

  searchStockPhotos () {
    const url = new URL(this.stockPhotosUrlValue, window.location.href)
    url.searchParams.set('manufacturer', this.stockManufacturerTarget.value)
    url.searchParams.set('model', this.stockModelTarget.value)
    url.searchParams.set('year', this.stockYearTarget.value)
    url.searchParams.set('selected_url', this.radio('stock_photo_id')?.dataset.url || '')
    url.searchParams.set('selected_id', this.radio('stock_photo_id')?.value || '')
    this.stockPhotosFrameTarget.setAttribute('loading', 'eager')
    this.stockPhotosFrameTarget.src = url.toString()
  }

  navigate (step) {
    if (step === this.stepValue) return

    const url = new URL(window.location.href)
    url.searchParams.set('step', step)
    window.history.pushState(window.history.state, '', url)
    this.show(step, { focus: true })
    this.rememberStep(step)
  }

  show (step, { focus = false } = {}) {
    this.stepValue = step
    this.visited.add(step)
    this.panelTargets.forEach((panel) => collapse(panel.dataset.step === step ? 'show' : 'hide', panel, 0))
    this.railItemTargets.forEach((item) => {
      if (item.dataset.step === step) return item.setAttribute('aria-current', 'step')

      item.removeAttribute('aria-current')
    })
    const index = this.stepsValue.indexOf(step)
    this.progressSegmentTargets.forEach((segment, segmentIndex) => { segment.dataset.filled = segmentIndex <= index + this.offsetValue })
    this.backButtonTarget.classList.toggle('tw:invisible', index === 0)
    collapse(step === 'review' ? 'hide' : 'show', this.continueButtonTarget, 0)
    collapse(step === 'review' || this.editingValue ? 'show' : 'hide', this.submitButtonTarget, 0)
    this.refresh()

    if (!focus) return

    // The heading names the step for a screen reader, and keeps the keyboard out of the step that just left
    this.currentPanel.querySelector('[data-step-heading]')?.focus({ preventScroll: true })
    this.element.scrollIntoView({ block: 'start', behavior: 'smooth' })
  }

  // Everything that follows from the answers: the rail, the review, what's shown beside them
  refresh () {
    if (this.hasValueUnknownTarget) {
      this.estimatedValueTarget.disabled = this.valueUnknownTarget.checked
      if (this.valueUnknownTarget.checked) this.estimatedValueTarget.value = ''
    }
    this.element.querySelectorAll('[data-show-when]').forEach((element) => {
      const [name, value] = element.dataset.showWhen.split('=')
      collapse(this.element.querySelector(`input[name="${name}"]:checked`)?.value === value ? 'show' : 'hide', element, 0)
    })
    const driveSide = this.photoAdded('drive_side')
    collapse(driveSide ? 'show' : 'hide', this.photoAddedTarget, 0)
    collapse(driveSide ? 'hide' : 'show', this.stockPhotosTarget, 0)

    this.railItemTargets.forEach((item, index) => {
      const step = item.dataset.step
      const done = this.complete(step)
      const skipped = !done && step !== this.stepValue && step !== 'review' && this.visited.has(step)
      item.dataset.done = done
      this.railMarkerTargets[index].textContent = done && step !== this.stepValue ? '✓' : index + 1 + this.offsetValue
      this.railNoteTargets[index].dataset.skipped = skipped
      this.railNoteTargets[index].textContent = step === this.stepValue
        ? this.textValue.in_progress
        : (done ? this.textValue.done : (skipped ? this.textValue.skipped : ''))
    })
    this.summaryTargets.forEach((summary, index) => {
      const step = summary.dataset.step
      const text = this.summary(step)
      summary.textContent = text || this.textValue.not_added
      summary.dataset.missing = !text
      this.summaryLinkTargets[index].textContent = this.complete(step) ? this.textValue.edit : this.textValue.add
    })
    const skippable = this.optionalValue.includes(this.stepValue) && !this.complete(this.stepValue)
    collapse(skippable ? 'show' : 'hide', this.skipButtonTarget, 0)
    const position = this.textValue.step_of
      .replace('%{number}', this.stepsValue.indexOf(this.stepValue) + 1 + this.offsetValue)
      .replace('%{total}', this.stepsValue.length + this.offsetValue)
    this.progressLabelTarget.textContent = [this.textValue.progress_saved, this.label(this.stepValue), position]
      .filter(Boolean).join(' · ')
    if (this.hasMobileStepTarget) this.mobileStepTarget.textContent = `${position} · ${this.label(this.stepValue)}`
    this.panelTargets.forEach((panel) => this.clearFixedErrors(panel))
  }

  complete (step) {
    switch (step) {
      case 'where': return !!(this.value('date') && this.value('city') && this.value('postal_code')) && !this.futureDate()
      case 'lock': return !!this.value('theft_description')
      case 'photos': return this.photoAdded('drive_side') || !!this.radio('stock_photo_id')
      case 'police': return !!(this.value('police_report_number') && this.value('police_report_department'))
      case 'contact': return !!this.value('phone')
      case 'extra': return !!((this.value('estimated_value') || this.checked('value_unknown')) && this.radio('proof_of_ownership'))
      default: return false
    }
  }

  summary (step) {
    const text = this.textValue
    switch (step) {
      case 'where': {
        if (!this.value('city')) return ''
        const when = [this.formattedDate(), this.value('time') && `${text.around} ${this.formattedTime()}`].filter(Boolean).join(' ')
        const place = [this.value('street'), this.value('city'), this.region(), this.value('postal_code')].filter(Boolean).join(', ')
        return [when, place].filter(Boolean).join(' · ')
      }
      case 'lock': {
        const lock = [this.radio('locking_description'), this.radio('lock_defeat_description')].filter(Boolean)
          .map((radio) => this.radioLabel(radio))
        const description = this.value('theft_description')
        return [...lock, description.length > 80 ? `${description.slice(0, 80)}…` : description].filter(Boolean).join(' · ')
      }
      case 'photos': {
        const added = this.element.querySelectorAll('[data-photo-added="true"]').length
        if (added) return text.photos_added.replace('%{number}', added)
        return this.radio('stock_photo_id') ? text.stock_photo : ''
      }
      case 'police': {
        if (this.value('police_report_number')) return [this.value('police_report_number'), this.value('police_report_department')].filter(Boolean).join(' · ')
        return this.element.querySelector('input[name="police_report_status"]:checked')?.value === 'none' ? text.no_report : ''
      }
      case 'contact': {
        if (!this.value('phone')) return ''
        const visibleTo = [['phone_for_police', text.police], ['phone_for_shops', text.shops], ['phone_for_users', text.users]]
          .filter(([name]) => this.checked(name)).map(([, label]) => label)
        return [this.value('phone'), visibleTo.length && `${text.visible_to} ${visibleTo.join(', ')}`].filter(Boolean).join(' · ')
      }
      case 'extra': {
        const value = this.checked('value_unknown') ? text.value_unknown : this.formattedValue()
        const proof = this.radio('proof_of_ownership')
        return [value, proof && text.proof.replace('%{answer}', this.radioLabel(proof))].filter(Boolean).join(' · ')
      }
      default: return ''
    }
  }

  // Marks the required fields left empty, and a date that hasn't happened yet - only on the shown
  // step unless asked to
  validate (panel, mark = true) {
    const invalid = [...panel.querySelectorAll('[required]')].filter((field) => !field.disabled && this.problem(field))
    if (mark) {
      invalid.forEach((field) => {
        field.setAttribute('aria-invalid', 'true')
        this.showError(panel, field, this.problem(field))
      })
      invalid[0]?.focus()
    }
    return invalid.length === 0
  }

  // 'required', 'future', or nothing
  problem (field) {
    if (!field.value.trim()) return 'required'
    if (field.type === 'date' && field.max && field.value > field.max) return 'future'
  }

  showError (panel, field, problem) {
    const name = field.id.replace('stolen_record_', '')
    panel.querySelectorAll(`[data-error-for="${name}"]`).forEach((error) => {
      collapse(error.dataset.problem === problem || (!error.dataset.problem && problem === 'required') ? 'show' : 'hide', error, 0)
    })
  }

  clearFixedErrors (panel) {
    panel.querySelectorAll('[aria-invalid="true"]').forEach((field) => {
      if (this.problem(field)) return

      field.removeAttribute('aria-invalid')
      panel.querySelectorAll(`[data-error-for="${field.id.replace('stolen_record_', '')}"]`)
        .forEach((error) => collapse('hide', error, 0))
    })
  }

  localizeDateStolen () {
    const initial = this.dateTarget.dataset.initial
    if (!initial) return

    const date = new Date(initial)
    const pad = (number) => String(number).padStart(2, '0')
    this.dateTarget.value = `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())}`
    this.timeTarget.value = `${pad(date.getHours())}:${pad(date.getMinutes())}`
  }

  futureDate () {
    return this.problem(this.dateTarget) === 'future'
  }

  formattedDate () {
    const [year, month, day] = this.value('date').split('-').map(Number)
    if (!year) return this.value('date')

    return new Intl.DateTimeFormat(undefined, { dateStyle: 'medium' }).format(new Date(year, month - 1, day))
  }

  formattedTime () {
    const [hours, minutes] = this.value('time').split(':').map(Number)
    return new Intl.DateTimeFormat(undefined, { timeStyle: 'short' }).format(new Date(2000, 0, 1, hours, minutes))
  }

  formattedValue () {
    const value = Number(this.value('estimated_value'))
    if (!value) return ''

    try {
      return new Intl.NumberFormat(undefined, { style: 'currency', currency: this.currencyValue, maximumFractionDigits: 0 }).format(value)
    } catch {
      return String(value)
    }
  }

  // The US state's combobox shows its name, the region field its text - whichever the country asks for
  region () {
    const state = this.element.querySelector('[data-ui--forms--address-group-target="state"]:not(.tw\\:hidden) input[role="combobox"]')
    return state ? state.value.trim() : this.value('region_string')
  }

  // A new report's draft is kept by form-persist; this keeps which step it was on
  resumedStep () {
    if (!this.draftKeyValue || new URL(window.location.href).searchParams.get('step')) return

    try {
      const saved = JSON.parse(window.localStorage.getItem(this.draftKeyValue) || 'null')
      if (saved && Date.now() - saved.savedAt < STEP_TTL_MS && this.stepsValue.includes(saved.step)) return saved.step
    } catch {}
  }

  rememberStep (step) {
    if (!this.draftKeyValue) return

    try { window.localStorage.setItem(this.draftKeyValue, JSON.stringify({ step, savedAt: Date.now() })) } catch {}
  }

  forgetStep () {
    if (!this.draftKeyValue) return

    try { window.localStorage.removeItem(this.draftKeyValue) } catch {}
  }

  photoAdded (kind) {
    return !!this.element.querySelector(`[data-photo-kind="${kind}"][data-photo-added="true"]`)
  }

  stepAt (offset) {
    const index = this.stepsValue.indexOf(this.stepValue) + offset
    return this.stepsValue[Math.min(Math.max(index, 0), this.stepsValue.length - 1)]
  }

  label (step) {
    return this.railItemTargets.find((item) => item.dataset.step === step)?.querySelector('[data-step-label]')?.textContent.trim() || ''
  }

  panelFor (step) {
    return this.panelTargets.find((panel) => panel.dataset.step === step)
  }

  get currentPanel () {
    return this.panelFor(this.stepValue)
  }

  value (name) {
    const field = this.element.querySelector(`[name="stolen_record[${name}]"]:not([type="hidden"]):not([type="radio"]):not([type="checkbox"])`)
    return (field?.value || '').trim()
  }

  checked (name) {
    return !!this.element.querySelector(`input[type="checkbox"][name="stolen_record[${name}]"]:checked`)
  }

  radio (name) {
    return this.element.querySelector(`input[type="radio"][name="stolen_record[${name}]"]:checked`)
  }

  radioLabel (radio) {
    return radio.closest('label')?.textContent.trim().replace(/\s+/g, ' ') || radio.value
  }
}
