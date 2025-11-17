import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
    static targets = [
        "masterCheckbox",
        "checkbox",
        "assignButton",
        "counter",
        "countDisplay",
        "selectAllButton",
        "clearButton",
        "newTourLink"
    ]

    connect() {
        console.log('MultiSelect controller connected')
        this.updateUI()

        // Listen für Custom Events aus dem Backend
        document.addEventListener('delivery_positions:assigned', this.handlePositionsAssigned.bind(this))
        document.addEventListener('delivery_position:unassigned', this.handlePositionUnassigned.bind(this))

        // Listen für Turbo Stream Events
        document.addEventListener('turbo:before-stream-render', this.handleTurboStreamRender.bind(this))
    }

    disconnect() {
        document.removeEventListener('delivery_positions:assigned', this.handlePositionsAssigned.bind(this))
        document.removeEventListener('delivery_position:unassigned', this.handlePositionUnassigned.bind(this))
        document.removeEventListener('turbo:before-stream-render', this.handleTurboStreamRender.bind(this))
    }

    // Handle successful delivery position assignment from backend
    handlePositionsAssigned(event) {
        console.log('Delivery positions assigned event received:', event.detail)

        // Auswahl zurücksetzen nach erfolgreichem Assignment
        setTimeout(() => {
            this.clearAllSelections()
            this.updateUI()
        }, 100)
    }

    // Handle delivery position unassigned event
    handlePositionUnassigned(event) {
        console.log('Delivery position unassigned event received:', event.detail)

        // UI nach kurzer Verzögerung aktualisieren (DOM Update abwarten)
        setTimeout(() => {
            this.updateUI()
        }, 200)
    }

    // Handle Turbo Stream rendering
    handleTurboStreamRender(event) {
        // Nach Turbo Stream Updates UI neu initialisieren
        if (event.detail && event.detail.render) {
            setTimeout(() => {
                this.updateUI()
            }, 50)
        }
    }

    // Master checkbox toggle
    toggleMaster() {
        const isChecked = this.masterCheckboxTarget.checked

        this.checkboxTargets.forEach(checkbox => {
            checkbox.checked = isChecked
        })

        this.updateUI()
    }

    // Individual checkbox changed
    checkboxChanged() {
        this.updateUI()
    }

    // Select all delivery positions
    selectAll(event) {
        event.preventDefault()

        this.checkboxTargets.forEach(checkbox => {
            checkbox.checked = true
        })

        if (this.hasMasterCheckboxTarget) {
            this.masterCheckboxTarget.checked = true
        }

        this.updateUI()
    }

    // Clear all selections
    clearSelection(event) {
        event.preventDefault()
        this.clearAllSelections()
    }

    // Internal method to clear all selections
    clearAllSelections() {
        this.checkboxTargets.forEach(checkbox => {
            checkbox.checked = false
        })

        if (this.hasMasterCheckboxTarget) {
            this.masterCheckboxTarget.checked = false
            this.masterCheckboxTarget.indeterminate = false
        }

        this.updateUI()
    }

    // NEW: Controlled new tour creation
    createNewTour(event) {
        event.preventDefault()

        const selectedIds = this.getSelectedIds()

        // GUARD: Nur wenn Positionen ausgewählt sind
        if (selectedIds.length === 0) {
            alert('Bitte wählen Sie mindestens eine Position aus, um eine neue Tour zu erstellen.')
            return
        }

        // Confirmation
        const confirmation = confirm(`Neue Tour mit ${selectedIds.length} Position${selectedIds.length === 1 ? '' : 'en'} erstellen?`)
        if (!confirmation) {
            return
        }

        // Button temporär disablen
        const button = event.currentTarget
        button.disabled = true
        button.classList.add('btn--loading')

        // CSRF Token
        const csrfToken = document.querySelector('[name="csrf-token"]')?.content

        // POST Request zu /tours (Rails Convention)
        fetch('/tours', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'X-CSRF-Token': csrfToken,
                'Accept': 'application/json'
            },
            body: JSON.stringify({
                position_ids: selectedIds.join(',')
            })
        })
            .then(response => response.json())
            .then(data => {
                if (data.success) {
                    // Show success message
                    this.showFlashMessage(data.message, 'success')

                    // Redirect zur Tours Seite nach kurzer Verzögerung
                    setTimeout(() => {
                        window.location.href = '/tours'
                    }, 1000)
                } else {
                    alert(data.message || 'Fehler beim Erstellen der Tour')
                    button.disabled = false
                    button.classList.remove('btn--loading')
                }
            })
            .catch(error => {
                console.error('Error:', error)
                alert('Fehler beim Erstellen der Tour')
                button.disabled = false
                button.classList.remove('btn--loading')
            })
    }

    // Handle batch assignment to tour
    assignToTour(event) {
        event.preventDefault()

        const selectedIds = this.getSelectedIds()

        if (selectedIds.length === 0) {
            alert('Bitte wählen Sie mindestens eine Position aus.')
            return
        }

        const button = event.currentTarget
        const tourId = button.dataset.tourId
        const url = button.dataset.url

        if (!tourId || !url) {
            console.error('Missing tourId or URL for batch assignment')
            return
        }

        // Button temporär disablen während Request
        button.disabled = true
        button.classList.add('btn--loading')

        this.submitAssignment(url, tourId, selectedIds)
    }

    // Update all UI elements based on current selection
    updateUI() {
        const selectedCount = this.getSelectedCount()
        const totalCount = this.checkboxTargets.length

        // Update selection counter
        this.updateCounter(selectedCount)

        // Update assign buttons
        this.updateAssignButtons(selectedCount)

        // Update master checkbox
        this.updateMasterCheckbox(selectedCount, totalCount)

        // Update row highlighting
        this.updateRowHighlighting()

        // Update neue tour button
        this.updateNewTourLink(selectedCount)
    }

    // Update selection counter display
    updateCounter(count) {
        if (this.hasCountDisplayTarget) {
            this.countDisplayTargets.forEach(target => {
                target.textContent = count
            })
        }

        if (this.hasCounterTarget) {
            this.counterTarget.style.display = count > 0 ? 'block' : 'none'
        }
    }

    // Update assign button states
    updateAssignButtons(count) {
        this.assignButtonTargets.forEach(button => {
            const isDisabled = count === 0

            button.disabled = isDisabled

            // Entferne Loading-Klasse
            button.classList.remove('btn--loading')

            // Verwende dein Design System
            if (isDisabled) {
                button.classList.remove('btn--success')
                button.classList.add('btn--secondary')
            } else {
                button.classList.remove('btn--secondary')
                button.classList.add('btn--success')
            }

            // Update count badge
            const countBadge = button.querySelector('.count-badge')
            if (countBadge) {
                countBadge.setAttribute('data-count', count.toString())
                countBadge.textContent = count

                if (count > 0) {
                    countBadge.style.display = 'flex'
                } else {
                    countBadge.style.display = 'none'
                }
            }

            // Update button text
            const buttonText = button.querySelector('.button-text')
            if (buttonText) {
                if (count > 0) {
                    buttonText.textContent = count === 1
                        ? 'Hinzufügen (1)'
                        : `Hinzufügen (${count})`
                } else {
                    buttonText.textContent = 'Hinzufügen'
                }
            }
        })
    }

    // Update master checkbox state (checked/indeterminate/unchecked)
    updateMasterCheckbox(selectedCount, totalCount) {
        if (!this.hasMasterCheckboxTarget) return

        if (selectedCount === 0) {
            this.masterCheckboxTarget.indeterminate = false
            this.masterCheckboxTarget.checked = false
        } else if (selectedCount === totalCount) {
            this.masterCheckboxTarget.indeterminate = false
            this.masterCheckboxTarget.checked = true
        } else {
            this.masterCheckboxTarget.indeterminate = true
            this.masterCheckboxTarget.checked = false
        }
    }

    // Update table row highlighting
    updateRowHighlighting() {
        this.checkboxTargets.forEach(checkbox => {
            const row = checkbox.closest('tr')
            if (row) {
                row.classList.toggle('selected', checkbox.checked)
            }
        })
    }

    // UPDATED: Update "Neue Tour" button with selected delivery positions
    updateNewTourLink(count) {
        if (!this.hasNewTourLinkTarget) return

        const button = this.newTourLinkTarget

        if (count > 0) {
            // Visual feedback dass Positionen zugewiesen werden
            button.classList.add('btn--success')
            button.classList.remove('btn--primary')
            button.disabled = false

            // Update button text
            const linkText = button.querySelector('span:last-child') || button
            if (count === 1) {
                linkText.innerHTML = 'Neue Tour<br><small>(1 Position)</small>'
            } else {
                linkText.innerHTML = `Neue Tour<br><small>(${count} Positionen)</small>`
            }
        } else {
            // Reset button wenn keine Auswahl
            button.classList.remove('btn--success')
            button.classList.add('btn--primary')
            button.disabled = true  // WICHTIG: Button disablen

            // Reset button text
            const linkText = button.querySelector('span:last-child') || button
            linkText.innerHTML = 'Neue Tour'
        }
    }

    // Get selected delivery position IDs
    getSelectedIds() {
        return this.checkboxTargets
            .filter(checkbox => checkbox.checked)
            .map(checkbox => checkbox.value)
    }

    // Get count of selected checkboxes
    getSelectedCount() {
        return this.checkboxTargets.filter(checkbox => checkbox.checked).length
    }

    // Get selected delivery position data for analysis
    getSelectedData() {
        return this.checkboxTargets
            .filter(checkbox => checkbox.checked)
            .map(checkbox => ({
                id: checkbox.value,
                customer: checkbox.dataset.customer,
                weight: parseFloat(checkbox.dataset.weight) || 0
            }))
    }

    // Submit batch assignment form - VEREINFACHT FÜR JSON
    submitAssignment(url, tourId, positionIds) {
        // Einfacher AJAX Request statt Form-Submit
        const data = {
            tour_id: tourId,
            position_ids: positionIds
        }

        // CSRF Token
        const csrfToken = document.querySelector('[name="csrf-token"]')?.content

        fetch(url, {
            method: 'PATCH',
            headers: {
                'Content-Type': 'application/json',
                'X-CSRF-Token': csrfToken,
                'Accept': 'application/json'
            },
            body: JSON.stringify(data)
        })
            .then(response => response.json())
            .then(data => {
                // Re-enable buttons
                this.assignButtonTargets.forEach(button => {
                    button.disabled = false
                    button.classList.remove('btn--loading')
                })

                if (data.success) {
                    console.log('Assignment successful:', data.message)

                    // Show success message
                    this.showFlashMessage(data.message, 'success')

                    // Custom event dispatchen
                    document.dispatchEvent(new CustomEvent('delivery_positions:assigned', {
                        detail: { tourId: tourId, positionIds: positionIds, message: data.message }
                    }))

                    // Page refresh als einfache Lösung für jetzt
                    setTimeout(() => {
                        window.location.reload()
                    }, 1000)

                } else {
                    console.error('Assignment failed:', data.message)
                    this.showFlashMessage(data.message, 'error')
                }
            })
            .catch(error => {
                console.error('Network error:', error)

                // Re-enable buttons
                this.assignButtonTargets.forEach(button => {
                    button.disabled = false
                    button.classList.remove('btn--loading')
                })

                this.showFlashMessage('Netzwerkfehler beim Zuweisen der Positionen', 'error')
            })
    }

    // Helper für Flash Messages
    showFlashMessage(message, type) {
        // Erstelle Flash Message Element
        const flashContainer = document.getElementById('flash_messages') || this.createFlashContainer()

        const messageEl = document.createElement('div')
        messageEl.className = `alert alert--${type} alert-dismissible`
        messageEl.setAttribute('data-flash-messages-target', 'message')

        messageEl.innerHTML = `
            ${message}
            <button type="button" class="alert-close" data-action="click->flash-messages#close">×</button>
        `

        flashContainer.appendChild(messageEl)

        // Auto-close nach 5 Sekunden
        setTimeout(() => {
            if (messageEl.parentNode) {
                messageEl.style.opacity = '0'
                messageEl.style.transform = 'translateX(100%)'
                setTimeout(() => messageEl.remove(), 300)
            }
        }, 5000)
    }

    // Flash Container erstellen falls nicht vorhanden
    createFlashContainer() {
        const container = document.createElement('div')
        container.id = 'flash_messages'
        container.setAttribute('data-controller', 'flash-messages')
        container.setAttribute('data-flash-messages-auto-close-value', 'true')

        // Container am Anfang der main-content einfügen
        const mainContent = document.querySelector('.main-content')
        if (mainContent) {
            mainContent.insertBefore(container, mainContent.firstChild)
        } else {
            document.body.insertBefore(container, document.body.firstChild)
        }

        return container
    }

    // Helper to add hidden input - WIEDER HINZUGEFÜGT
    addInput(form, name, value) {
        const input = document.createElement('input')
        input.type = 'hidden'
        input.name = name
        input.value = value
        form.appendChild(input)
    }

    // Public API methods

    // Get selection statistics
    getStats() {
        const data = this.getSelectedData()
        const totalWeight = data.reduce((sum, item) => sum + item.weight, 0)
        const customers = [...new Set(data.map(item => item.customer))]

        return {
            count: data.length,
            totalWeight,
            customers,
            averageWeight: data.length > 0 ? totalWeight / data.length : 0
        }
    }

    // Programmatically select delivery positions
    selectPositions(ids) {
        this.checkboxTargets.forEach(checkbox => {
            if (ids.includes(checkbox.value)) {
                checkbox.checked = true
            }
        })
        this.updateUI()
    }

    // Programmatically clear selection
    clearAll() {
        this.clearAllSelections()
    }

    // Check if has selection
    hasSelection() {
        return this.getSelectedCount() > 0
    }

    // Force refresh UI (useful after DOM changes)
    refreshUI() {
        setTimeout(() => {
            this.updateUI()
        }, 100)
    }
}