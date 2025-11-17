import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
    static targets = ["message"]
    static values = {
        autoClose: { type: Boolean, default: true },
        delay: { type: Number, default: 5000 }
    }

    connect() {
        // Einblende-Animation
        this.element.style.opacity = '0'
        this.element.style.transform = 'translateX(100%)'

        // Kurz warten, dann einblenden
        requestAnimationFrame(() => {
            this.element.style.transition = 'all 0.3s ease'
            this.element.style.opacity = '1'
            this.element.style.transform = 'translateX(0)'
        })

        if (this.autoCloseValue) {
            this.startAutoClose()
        }
    }

    disconnect() {
        if (this.timeout) {
            clearTimeout(this.timeout)
        }
    }

    startAutoClose() {
        this.timeout = setTimeout(() => {
            this.closeAll()
        }, this.delayValue)
    }

    close(event) {
        event.preventDefault()
        const messageElement = event.currentTarget.closest('[data-flash-messages-target="message"]')
        this.closeMessage(messageElement)
    }

    closeMessage(messageElement) {
        messageElement.style.transition = 'all 0.3s ease'
        messageElement.style.opacity = '0'
        messageElement.style.transform = 'translateX(100%)'

        setTimeout(() => {
            messageElement.remove()
            this.checkIfEmpty()
        }, 300)
    }

    closeAll() {
        this.element.style.transition = 'all 0.3s ease'
        this.element.style.opacity = '0'
        this.element.style.transform = 'translateX(100%)'

        setTimeout(() => {
            this.element.remove()
        }, 300)
    }

    checkIfEmpty() {
        if (this.messageTargets.length === 0) {
            this.closeAll()
        }
    }

    // Neue Methode zum Pausieren des Auto-Close bei Hover
    pauseAutoClose() {
        if (this.timeout) {
            clearTimeout(this.timeout)
        }
    }

    // Neue Methode zum Fortsetzen des Auto-Close
    resumeAutoClose() {
        if (this.autoCloseValue) {
            this.startAutoClose()
        }
    }
}