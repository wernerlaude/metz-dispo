import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
    static values = { tourId: String }
    static targets = ["list", "item"]

    connect() {
        this.setupSortable()
    }

    setupSortable() {
        if (!this.hasListTarget) return

        this.listTarget.addEventListener('dragover', this.dragOver.bind(this))
        this.listTarget.addEventListener('drop', this.drop.bind(this))
        this.setupDraggableItems()
    }

    setupDraggableItems() {
        this.itemTargets.forEach(item => {
            const handle = item.querySelector('.drag-handle')
            if (handle) {
                item.draggable = true
                item.addEventListener('dragstart', this.dragStart.bind(this))
                item.addEventListener('dragend', this.dragEnd.bind(this))

                handle.addEventListener('mousedown', () => item.setAttribute('draggable', 'true'))
                item.addEventListener('mouseup', () => item.setAttribute('draggable', 'false'))
            }
        })
    }

    dragStart(event) {
        this.draggedElement = event.target.closest('[data-sortable-target="item"]')
        if (!this.draggedElement) return

        this.draggedElement.classList.add('dragging')
        this.draggedElement.style.opacity = '0.5'
        event.dataTransfer.effectAllowed = 'move'
    }

    dragEnd(event) {
        if (this.draggedElement) {
            this.draggedElement.classList.remove('dragging')
            this.draggedElement.style.opacity = ''
            this.draggedElement = null
        }
        this.itemTargets.forEach(item => item.classList.remove('drop-above', 'drop-below'))
    }

    dragOver(event) {
        event.preventDefault()
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
        if (!this.draggedElement) return

        this.itemTargets.forEach(item => item.classList.remove('drop-above', 'drop-below'))
        setTimeout(() => this.updateSequence(), 100)
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
        const deliveryIds = Array.from(this.listTarget.querySelectorAll('[data-sortable-target="item"]'))
            .map(item => item.dataset.deliveryId)
            .filter(id => id)

        if (!deliveryIds.length || !this.tourIdValue) return

        try {
            const response = await fetch('/delivery_positions/reorder_in_tour', {
                method: 'PATCH',
                headers: {
                    'Content-Type': 'application/json',
                    'X-CSRF-Token': document.querySelector('[name="csrf-token"]')?.content
                },
                body: JSON.stringify({ tour_id: this.tourIdValue, position_ids: deliveryIds })
            })

            const result = await response.json()

            if (result.status === 'success') {
                this.updatePositionNumbers()
                this.showFeedback('Reihenfolge aktualisiert', 'success')
            } else {
                this.showFeedback('Fehler beim Sortieren', 'error')
            }
        } catch (error) {
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
        feedback.innerHTML = `${message}<button onclick="this.parentElement.remove()">×</button>`
        feedback.style.cssText = `
            position: fixed; top: 80px; right: 20px; z-index: 9999;
            padding: 12px 20px; border-radius: 8px; color: white;
            background: ${type === 'success' ? '#28a745' : '#dc3545'};
            transform: translateX(100%); transition: transform 0.3s;
        `

        document.body.appendChild(feedback)
        setTimeout(() => feedback.style.transform = 'translateX(0)', 10)
        setTimeout(() => feedback.remove(), 3000)
    }

    refresh() {
        this.setupDraggableItems()
    }
}