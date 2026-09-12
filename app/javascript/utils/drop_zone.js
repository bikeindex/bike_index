// The drag framing the file upload controllers share: a frame that lights up while a file is
// over it, and the FileList a drop hands to an input.

// Dragged text and page elements fire these events too; only files matter here.
export function draggingFile (event) {
  return event.dataTransfer?.types?.includes('Files')
}

export function dragOver (event, frame) {
  if (!draggingFile(event)) return
  event.preventDefault() // without this the browser opens the file instead

  frame.dataset.dragging = 'true'
}

// Bound to both dragleave and drop. dragleave fires for every element crossed, but
// relatedTarget is null only on leaving the window -- and on a drop, which ends it too.
export function endDrag (event, frame) {
  if (event.relatedTarget) return
  event.preventDefault()

  delete frame.dataset.dragging
  unhighlight(event, frame)
}

export function highlight (frame) {
  frame.dataset.over = 'true'
}

// The frame wraps the controls, so dragging onto one of them leaves the frame
// in the event's terms -- only a relatedTarget outside it is a real exit.
export function unhighlight (event, frame) {
  if (event?.relatedTarget && frame.contains(event.relatedTarget)) return

  delete frame.dataset.over
}

// Assigning a FileList is the only way to fill a file input; `multiple`
// decides how much of the drop it can hold.
export function assignDroppedFiles (event, input) {
  event.preventDefault()
  const dropped = [...event.dataTransfer.files]
  if (dropped.length === 0) return

  const transfer = new window.DataTransfer()
  ;(input.multiple ? dropped : dropped.slice(0, 1)).forEach((file) => transfer.items.add(file))
  input.files = transfer.files
  // Assigning files fires nothing. Picking a file natively fires both, and both
  // have listeners: `input` drives the controller, `change` is what callers bind to.
  input.dispatchEvent(new Event('input', { bubbles: true }))
  input.dispatchEvent(new Event('change', { bubbles: true }))
}
