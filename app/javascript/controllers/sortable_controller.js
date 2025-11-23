// app/javascript/controllers/sortable_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
    static values = { tourId: String }
    static targets = ["list", "item"]

    connect() {
        console.log("Sortable Controller connected for tour:", this.tourIdValue)
        this.setupSortable()
    }

    setupSortable() {
        if (!this.hasListTarget) {
            console.warn("No list target found")
            return
        }

        this.listTarget.addEventListener('dragover', this.dragOver.bind(this))
        this.listTarget.addEventListener('drop', this.drop.bind(this))
        this.listTarget.addEventListener('dragenter', this.dragEnter.bind(this))
        this.setupDraggableItems()
    }

    setupDraggableItems() {
        this.itemTargets.forEach(item => {
            const handle = item.querySelector('.drag-handle')
            if (handle) {
                item.draggable = true
                item.addEventListener('dragstart', this.dragStart.bind(this))
                item.addEventListener('dragend', this.dragEnd.bind(this))
            }
        })
    }

    dragStart(event) {
        this.draggedElement = event.target.closest('[data-sortable-target="item"]')
        if (!this.draggedElement) return

        console.log("Drag started:", this.draggedElement.dataset.deliveryId)

        this.draggedElement.classList.add('dragging')
        this.draggedElement.style.opacity = '0.5'
        event.dataTransfer.effectAllowed = 'move'
        event.dataTransfer.setData('text/plain', this.draggedElement.dataset.deliveryId)
    }

    dragEnd(event) {
        console.log("Drag ended")
        if (this.draggedElement) {
            this.draggedElement.classList.remove('dragging')
            this.draggedElement.style.opacity = ''
            this.draggedElement = null
        }
        this.itemTargets.forEach(item => item.classList.remove('drop-above', 'drop-below'))
    }

    dragEnter(event) {
        event.preventDefault()
    }

    dragOver(event) {
        event.preventDefault()
        event.dataTransfer.dropEffect = 'move'

        if (!this.draggedElement) return

        const afterElement = this.getDragAfterElement(event.clientY)
        this.itemTargets.forEach(item => item.classList.remove('drop-above', 'drop-below'))

        if (afterElement == null) {
            this.listTarget.appendChild(this.draggedElement)
        } else {
            this.listTarget.insertBefore(this.draggedElement, afterElement)
            afterElement.classList.add('drop-above')
        }
    }

    drop(event) {
        event.preventDefault()
        event.stopPropagation()

        console.log("Drop event triggered")

        if (!this.draggedElement) {
            console.warn("No dragged element found")
            return
        }

        this.itemTargets.forEach(item => item.classList.remove('drop-above', 'drop-below'))

        // Kleine Verzögerung damit DOM sich aktualisiert
        setTimeout(() => {
            this.updateSequence()
        }, 100)
    }

    getDragAfterElement(y) {
        const draggableElements = [...this.itemTargets.filter(item => item !== this.draggedElement)]

        return draggableElements.reduce((closest, child) => {
            const box = child.getBoundingClientRect()
            const offset = y - box.top - box.height / 2

            if (offset < 0 && offset > closest.offset) {
                return { offset: offset, element: child }
            }
            return closest
        }, { offset: Number.NEGATIVE_INFINITY }).element
    }

    async updateSequence() {
        const positionIds = Array.from(this.listTarget.querySelectorAll('[data-sortable-target="item"]'))
            .map((item, index) => {
                const deliveryId = item.dataset.deliveryId
                console.log(`Position ${index + 1}: ${deliveryId}`)
                return deliveryId
            })
            .filter(id => id)

        if (!positionIds.length) {
            console.warn("No position IDs found")
            return
        }

        if (!this.tourIdValue) {
            console.warn("No tour ID found")
            return
        }

        console.log("Updating sequence for tour:", this.tourIdValue)
        console.log("Position IDs:", positionIds)

        try {
            const response = await fetch('/delivery_positions/reorder_in_tour', {
                method: 'PATCH',
                headers: {
                    'Content-Type': 'application/json',
                    'X-CSRF-Token': document.querySelector('[name="csrf-token"]')?.content
                },
                body: JSON.stringify({
                    tour_id: this.tourIdValue,
                    position_ids: positionIds
                })
            })

            const result = await response.json()
            console.log("Server response:", result)

            if (result.status === 'success' || result.success) {
                this.updatePositionNumbers()
                this.showFeedback('Reihenfolge aktualisiert', 'success')
            } else {
                console.error("Server error:", result)
                this.showFeedback('Fehler beim Sortieren', 'error')
            }
        } catch (error) {
            console.error("Fetch error:", error)
            this.showFeedback('Fehler beim Sortieren', 'error')
        }
    }

    updatePositionNumbers() {
        this.listTarget.querySelectorAll('.position-badge').forEach((badge, index) => {
            badge.textContent = index + 1
        })
    }

    showFeedback(message, type) {
        document.querySelectorAll('.sort-feedback').forEach(el => el.remove())

        const feedback = document.createElement('div')
        feedback.className = 'sort-feedback'
        feedback.innerHTML = `${message} <button onclick="this.parentElement.remove()">×</button>`
        feedback.style.cssText = `
            position: fixed; top: 80px; right: 20px; z-index: 9999;
            padding: 12px 20px; border-radius: 8px; color: white;
            background: ${type === 'success' ? '#28a745' : '#dc3545'};
            box-shadow: 0 2px 8px rgba(0,0,0,0.2);
            transform: translateX(100%); transition: transform 0.3s;
        `

        document.body.appendChild(feedback)
        setTimeout(() => feedback.style.transform = 'translateX(0)', 10)
        setTimeout(() => {
            feedback.style.transform = 'translateX(100%)'
            setTimeout(() => feedback.remove(), 300)
        }, 3000)
    }

    refresh() {
        console.log("Refreshing sortable items")
        this.setupDraggableItems()
    }
}