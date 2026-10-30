const STEPS = { ArrowUp: -1, ArrowLeft: -1, ArrowDown: 1, ArrowRight: 1 }

// An arrow key on a UI::DragHandle moves its item one place, as a drop beside the neighbour would.
// items is a function, read again after the move, which leaves the moved item at the neighbour's index
export function moveByKey (event, items, move) {
  const step = STEPS[event.key]
  if (!step) return
  const before = items()
  const from = before.findIndex(item => item.contains(event.target))
  if (from === -1) return
  event.preventDefault()
  const index = from + step
  if (!before[index]) return
  move(before[from], before[index], step > 0)
  // Moving an element out of the DOM and back drops its focus
  const handle = items()[index].querySelector('[data-moved-message]')
  handle.focus()
  announce(handle.dataset.movedMessage.replace('%{position}', index + 1).replace('%{count}', before.length))
}

// Follows the pointer pressed in `down` until it's let go: move(event) as it moves, then drop()
// and done(). A gesture the browser takes over (pointercancel) skips the drop. Returns the function
// that stops following early, as a controller disconnecting mid-drag needs
export function followPointer (down, { move, drop, done }) {
  const ours = (event) => event.pointerId === down.pointerId
  const onMove = (event) => { if (ours(event)) move(event) }
  const onUp = (event) => {
    if (!ours(event)) return
    drop()
    finish()
  }
  const onCancel = (event) => { if (ours(event)) finish() }
  const finish = () => {
    document.removeEventListener('pointermove', onMove)
    document.removeEventListener('pointerup', onUp)
    document.removeEventListener('pointercancel', onCancel)
    done()
  }
  document.addEventListener('pointermove', onMove)
  document.addEventListener('pointerup', onUp)
  document.addEventListener('pointercancel', onCancel)
  return finish
}

// A drag starts from the main button, and from the first finger alone
export const startsDrag = (event) => event.button === 0 && event.isPrimary

// Emptied first so the same position, twice, is still said twice
function announce (message) {
  const status = liveRegion()
  status.textContent = ''
  window.requestAnimationFrame(() => { status.textContent = message })
}

// In place before the first move is said - one added as it changes goes unheard
function liveRegion () {
  const existing = document.getElementById('drag-handle-status')
  if (existing) return existing
  const region = document.createElement('div')
  region.id = 'drag-handle-status'
  region.className = 'tw:sr-only'
  region.setAttribute('role', 'status')
  return document.body.appendChild(region)
}

document.addEventListener('focusin', (event) => {
  if (event.target.matches?.('[data-moved-message]')) liveRegion()
})
