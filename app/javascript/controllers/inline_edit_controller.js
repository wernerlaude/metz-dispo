// app/javascript/controllers/inline_edit_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
    static targets = ["field"]

    connect() {
        console.log("Inline edit controller connected")
    }

    editField(event) {
        const span = event.currentTarget
        const field = span.dataset.field
        const type = span.dataset.type
        const value = span.dataset.value
        const tourId = span.closest("tr").dataset.tourId

        console.log("Editing field:", field, "Type:", type, "Value:", value)

        // Erstelle Input/Select basierend auf Typ
        let input
        if (type === "select") {
            const optionsJson = span.dataset.options
            console.log("Creating select with options:", optionsJson)
            input = this.createSelect(value, field, optionsJson)
        } else {
            input = this.createInput(type, value, field)
        }

        // Ersetze span mit input
        span.style.display = "none"
        span.insertAdjacentElement("afterend", input)
        input.focus()

        // Event Listener
        if (type === "select") {
            input.addEventListener("change", () => this.saveField(input, span, tourId))
            input.addEventListener("keydown", (e) => {
                if (e.key === "Escape") {
                    this.cancelEdit(input, span)
                }
            })
        } else {
            input.addEventListener("blur", () => this.saveField(input, span, tourId))
            input.addEventListener("keydown", (e) => {
                if (e.key === "Enter") {
                    e.preventDefault()
                    this.saveField(input, span, tourId)
                } else if (e.key === "Escape") {
                    this.cancelEdit(input, span)
                }
            })
        }
    }

    createInput(type, value, field) {
        const input = document.createElement("input")
        input.type = type === "datetime" ? "datetime-local" : type
        input.value = value || ""
        input.className = "form-control form-control-sm inline-input"
        input.dataset.field = field

        if (type === "number") {
            input.step = "any"
        }

        return input
    }

    createSelect(value, field, optionsJson) {
        const select = document.createElement("select")
        select.className = "form-select form-select-sm inline-select"
        select.dataset.field = field

        // Parse JSON options
        let options = []
        try {
            if (optionsJson) {
                options = JSON.parse(optionsJson)
                console.log("Parsed options:", options)
            }
        } catch (e) {
            console.error("Failed to parse options:", e, optionsJson)
        }

        // Leere Option
        const emptyOption = document.createElement("option")
        emptyOption.value = ""
        emptyOption.textContent = "-"
        select.appendChild(emptyOption)

        // Füge alle Options hinzu
        options.forEach(opt => {
            const option = document.createElement("option")
            option.value = opt.value
            option.textContent = opt.text
            if (opt.value == value) {
                option.selected = true
            }
            select.appendChild(option)
        })

        console.log("Created select with", options.length, "options")
        return select
    }

    async saveField(input, span, tourId) {
        const field = input.dataset.field
        const value = input.value
        const isSelect = input.tagName === "SELECT"

        console.log("Saving field:", field, "Value:", value)

        try {
            const response = await fetch(`/tours/${tourId}`, {
                method: "PATCH",
                headers: {
                    "Content-Type": "application/json",
                    "X-CSRF-Token": document.querySelector("[name='csrf-token']").content
                },
                body: JSON.stringify({
                    tour: { [field]: value || null }
                })
            })

            if (response.ok) {
                // Aktualisiere Anzeige
                if (isSelect) {
                    const selectedOption = input.options[input.selectedIndex]
                    span.textContent = selectedOption.textContent
                } else {
                    span.textContent = this.formatValue(value, input.type)
                }
                span.dataset.value = value
                this.cleanupInput(input, span)

                // Success Animation
                span.classList.add('save-success')
                setTimeout(() => {
                    span.classList.remove('save-success')
                }, 2000)

            } else {
                console.error("Save failed:", response.status)
                this.showError(span)
                this.cancelEdit(input, span)
            }
        } catch (error) {
            console.error("Save error:", error)
            this.showError(span)
            this.cancelEdit(input, span)
        }
    }

    showError(span) {
        span.classList.add('save-error')
        setTimeout(() => {
            span.classList.remove('save-error')
        }, 2000)
    }

    cancelEdit(input, span) {
        this.cleanupInput(input, span)
    }

    cleanupInput(input, span) {
        input.remove()
        span.style.display = ""
    }

    formatValue(value, type) {
        if (!value) return "-"

        if (type === "datetime-local") {
            const date = new Date(value)
            return date.toLocaleString("de-DE", {
                day: "2-digit",
                month: "2-digit",
                hour: "2-digit",
                minute: "2-digit"
            })
        }

        if (type === "date") {
            const date = new Date(value)
            return date.toLocaleDateString("de-DE")
        }

        return value
    }

    async toggleCompleted(event) {
        const checkbox = event.currentTarget
        const tourId = checkbox.dataset.tourId

        try {
            const response = await fetch(`/tours/${tourId}/toggle_completed`, {
                method: "PATCH",
                headers: {
                    "X-CSRF-Token": document.querySelector("[name='csrf-token']").content
                }
            })

            if (!response.ok) {
                checkbox.checked = !checkbox.checked
                alert("Fehler beim Aktualisieren")
            }
        } catch (error) {
            console.error("Toggle completed error:", error)
            checkbox.checked = !checkbox.checked
        }
    }

    async toggleSent(event) {
        const checkbox = event.currentTarget
        const tourId = checkbox.dataset.tourId

        try {
            const response = await fetch(`/tours/${tourId}/toggle_sent`, {
                method: "PATCH",
                headers: {
                    "X-CSRF-Token": document.querySelector("[name='csrf-token']").content
                }
            })

            if (!response.ok) {
                checkbox.checked = !checkbox.checked
                alert("Fehler beim Aktualisieren")
            }
        } catch (error) {
            console.error("Toggle sent error:", error)
            checkbox.checked = !checkbox.checked
        }
    }

    fieldTargetConnected(element) {
        element.addEventListener("click", this.editField.bind(this))
    }
}