import { noChange } from 'lit-html'
import { Directive, directive } from 'lit-html/directive.js'

// A component's **html_options: attributes named by the caller, which a template can't name in
// advance. A null or false value leaves its attribute out
export const attributes = directive(class extends Directive {
  render () {
    return noChange
  }

  update ({ element }, [values]) {
    for (const [name, value] of Object.entries(values)) {
      value == null || value === false ? element.removeAttribute(name) : element.setAttribute(name, value)
    }
    return noChange
  }
})
