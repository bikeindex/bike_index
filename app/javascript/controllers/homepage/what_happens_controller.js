import { Controller } from '@hotwired/stimulus'

// Connects to data-controller='homepage--what-happens'
export default class extends Controller {
  static targets = []
  static values = { steps: Array, currentStepIndex: { type: Number, default: 0 } }

  connect () {
    this.startBikeTransition()
  }

  // Bike transition animation
  startBikeTransition () {
    const bikeRegistered = document.getElementById('bikeRegistered')
    const bikeStolen = document.getElementById('bikeStolen')

    setInterval(() => {
      // Fade out registered, fade in stolen
      bikeRegistered.style.opacity = '0'
      bikeStolen.style.opacity = '1'

      setTimeout(() => {
        // Fade out stolen, fade in registered
        bikeRegistered.style.opacity = '1'
        bikeStolen.style.opacity = '0'
      }, 3000) // Show stolen for 3 seconds
    }, 6000) // Complete cycle every 6 seconds
  }

  // Next step
  nextStep () {
    this.currentStepIndexValue = (this.currentStepIndexValue + 1) % this.stepsValue.length
    this.updateStep(this.currentStepIndexValue)
  }

  // Previous step
  prevStep () {
    this.currentStepIndexValue = (this.currentStepIndexValue - 1 + this.stepsValue.length) % this.stepsValue.length
    this.updateStep(this.currentStepIndexValue)
  }

  updateStep (index) {
    const step = this.stepsValue[index]

    // Update text content
    const stepText = document.getElementById('stepText')
    stepText.innerHTML = `
      <h3>
        <span class="step-number">${step.stepNumber}</span>
        <span class="step-title">${step.title}</span>
      </h3>
      <p>${step.text}</p>
    `

    // Update background image
    document.getElementById('stepBackground').src = step.background

    // Rotate crank
    document.getElementById('bikeCrank').style.transform = `rotate(${step.rotation}deg)`

    // Update indicator
    document.getElementById('stepIndicator').textContent = `${index + 1} / 4`
  }
}
