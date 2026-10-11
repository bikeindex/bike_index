import { Controller } from '@hotwired/stimulus'
import { collapse } from 'utils/collapse_utils'

// Connects to data-controller='stolen-report--wizard'
// Every step of the report is on the page; this shows one at a time. Moving on checks only what the
// current step requires, the rail and the review say what each step holds, and submitting jumps back
// to the first step still missing something required
export default class extends Controller {
  static targets = [
    'panel', 'railItem', 'railMarker', 'railNote', 'progressSegment', 'progressLabel', 'summary', 'summaryLink',
    'backButton', 'skipButton', 'continueButton', 'submitButton', 'timezone', 'date', 'time',
    'photoAdded', 'stockPhotos', 'stockPhotosFrame', 'stockManufacturer', 'stockModel', 'stockYear',
    'estimatedValue', 'valueUnknown'
  ]

  static values = {
    step: String,
    steps: Array,
    optional: Array,
    // The register flow's steps, numbered ahead of these when it handed off here
    offset: Number,
    visited: Array,
    text: Object,
    stockPhotosUrl: String
  }

  connect () {
    this.timezoneTarget.value = Intl.DateTimeFormat().resolvedOptions().timeZone
    this.localizeDateStolen()
    this.visited = new Set(this.visitedValue)
    this.show(this.stepValue)
  }

  next () {
    if (!this.validate(this.currentPanel)) return

    this.show(this.stepAt(1), true)
  }

  skip () {
    this.show(this.stepAt(1), true)
  }

  back () {
    this.show(this.stepAt(-1), true)
  }

  goto ({ params: { step } }) {
    this.show(step, true)
  }

  submit (event) {
    const invalidStep = this.stepsValue.find((step) => !this.validate(this.panelFor(step), false))
    if (!invalidStep) return

    event.preventDefault()
    event.stopImmediatePropagation()
    this.show(invalidStep, true)
    this.validate(this.currentPanel)
  }

  searchStockPhotos () {
    const url = new URL(this.stockPhotosUrlValue, window.location.href)
    url.searchParams.set('manufacturer', this.stockManufacturerTarget.value)
    url.searchParams.set('model', this.stockModelTarget.value)
    url.searchParams.set('year', this.stockYearTarget.value)
    url.searchParams.set('selected_url', this.radio('stock_photo_id')?.dataset.url || '')
    this.stockPhotosFrameTarget.setAttribute('loading', 'eager')
    this.stockPhotosFrameTarget.src = url.toString()
  }

  show (step, navigated = false) {
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
    collapse(step === 'review' ? 'show' : 'hide', this.submitButtonTarget, 0)
    this.refresh()

    if (!navigated) return

    const url = new URL(window.location.href)
    url.searchParams.set('step', step)
    window.history.replaceState(window.history.state, '', url)
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
    this.progressLabelTarget.textContent = [
      this.textValue.progress_saved,
      this.label(this.stepValue),
      this.textValue.step_of
        .replace('%{number}', this.stepsValue.indexOf(this.stepValue) + 1 + this.offsetValue)
        .replace('%{total}', this.stepsValue.length + this.offsetValue)
    ].join(' · ')
    this.panelTargets.forEach((panel) => this.clearFixedErrors(panel))
  }

  complete (step) {
    switch (step) {
      case 'where': return !!(this.value('date') && this.value('city') && this.value('postal_code'))
      case 'lock': return !!(this.radio('locking_description') && this.radio('lock_defeat_description') && this.value('theft_description'))
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
        const when = [this.value('date'), this.value('time') && `${text.around} ${this.value('time')}`].filter(Boolean).join(' ')
        return [when, ['street', 'city', 'region_string', 'postal_code'].map((name) => this.value(name)).filter(Boolean).join(', ')]
          .filter(Boolean).join(' · ')
      }
      case 'lock': return [this.radio('locking_description'), this.radio('lock_defeat_description')].filter(Boolean)
        .map((radio) => this.radioLabel(radio)).join(' · ')
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
        const value = this.value('estimated_value') || (this.checked('value_unknown') && text.value_unknown)
        const proof = this.radio('proof_of_ownership')
        return [value, proof && text.proof.replace('%{answer}', this.radioLabel(proof))].filter(Boolean).join(' · ')
      }
      default: return ''
    }
  }

  // Marks the required fields left empty - only on the shown step unless asked to
  validate (panel, mark = true) {
    const empty = [...panel.querySelectorAll('[required]')].filter((field) => !field.disabled && !field.value.trim())
    if (mark) {
      empty.forEach((field) => {
        field.setAttribute('aria-invalid', 'true')
        const error = panel.querySelector(`[data-error-for="${field.id.replace('stolen_record_', '')}"]`)
        if (error) collapse('show', error, 0)
      })
      empty[0]?.focus()
    }
    return empty.length === 0
  }

  clearFixedErrors (panel) {
    panel.querySelectorAll('[aria-invalid="true"]').forEach((field) => {
      if (!field.value.trim()) return

      field.removeAttribute('aria-invalid')
      const error = panel.querySelector(`[data-error-for="${field.id.replace('stolen_record_', '')}"]`)
      if (error) collapse('hide', error, 0)
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

  photoAdded (kind) {
    return !!this.element.querySelector(`[data-photo-kind="${kind}"][data-photo-added="true"]`)
  }

  stepAt (offset) {
    const index = this.stepsValue.indexOf(this.stepValue) + offset
    return this.stepsValue[Math.min(Math.max(index, 0), this.stepsValue.length - 1)]
  }

  label (step) {
    return this.railItemTargets.find((item) => item.dataset.step === step)?.querySelector('span span')?.textContent.trim() || ''
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
