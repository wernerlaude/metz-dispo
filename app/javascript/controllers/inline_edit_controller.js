// app/javascript/controllers/inline_edit_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
    static targets = ["field"]

    connect() {
        console.log("Inline edit controller connected")

        // Prüfe Resource-Typ
        if (this.element.hasAttribute('data-driver-id')) {
            this.resourceType = 'driver'
            this.resourceId = this.element.dataset.driverId
        } else if (this.element.hasAttribute('data-tour-id')) {
            this.resourceType = 'tour'
            this.resourceId = this.element.dataset.tourId
        } else if (this.element.hasAttribute('data-loading-location-id')) {
            this.resourceType = 'loading_location'
            this.resourceId = this.element.dataset.loadingLocationId
        }

        console.log("Resource type:", this.resourceType, "ID:", this.resourceId)
    }

    editField(event) {
        const span = event.currentTarget
        const field = span.dataset.field
        const type = span.dataset.type
        const value = span.dataset.value

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
            input.addEventListener("change", () => this.saveField(input, span))
            input.addEventListener("keydown", (e) => {
                if (e.key === "Escape") {
                    this.cancelEdit(input, span)
                }
            })
        } else {
            input.addEventListener("blur", () => this.saveField(input, span))
            input.addEventListener("keydown", (e) => {
                if (e.key === "Enter") {
                    e.preventDefault()
                    this.saveField(input, span)
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

            // Verbesserte Vergleichslogik für null/undefined/empty values
            if (String(opt.value) === String(value) || (opt.value == value && value !== "" && value !== null)) {
                option.selected = true
            }

            select.appendChild(option)
        })

        // Wenn value leer/null ist, wähle die leere Option
        if (!value || value === "" || value === "null" || value === "undefined") {
            emptyOption.selected = true
        }

        console.log("Created select with", options.length, "options, selected value:", value)
        return select
    }

    async saveField(input, span) {
        const field = input.dataset.field
        const value = input.value
        const isSelect = input.tagName === "SELECT"

        console.log("Saving field:", field, "Value:", value, "Resource:", this.resourceType)

        // Dynamischer Endpoint basierend auf Resource-Typ
        let endpoint, bodyKey

        switch(this.resourceType) {
            case 'driver':
                endpoint = `/drivers/${this.resourceId}`
                bodyKey = 'driver'
                break
            case 'tour':
                endpoint = `/tours/${this.resourceId}`
                bodyKey = 'tour'
                break
            case 'loading_location':
                endpoint = `/loading_locations/${this.resourceId}`
                bodyKey = 'loading_location'
                break
            default:
                console.error("Unknown resource type:", this.resourceType)
                return
        }

        try {
            const response = await fetch(endpoint, {
                method: "PATCH",
                headers: {
                    "Content-Type": "application/json",
                    "X-CSRF-Token": document.querySelector("[name='csrf-token']").content
                },
                body: JSON.stringify({
                    [bodyKey]: { [field]: value || null }  // Sende null wenn leer
                })
            })

            if (response.ok) {
                // Aktualisiere Anzeige
                if (isSelect) {
                    const selectedOption = input.options[input.selectedIndex]
                    span.textContent = selectedOption.textContent
                    // Update data-value für nächstes Edit
                    span.dataset.value = value || ""
                } else {
                    span.textContent = this.formatValue(value, input.type)
                    span.dataset.value = value || ""
                }
                this.cleanupInput(input, span)

                // Success Animation
                span.classList.add('save-success')
                setTimeout(() => {
                    span.classList.remove('save-success')
                }, 2000)

            } else {
                console.error("Save failed:", response.status)
                const errorData = await response.json().catch(() => ({}))
                console.error("Error details:", errorData)
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

    // Toggle für Driver Active Status
    async toggleActive(event) {
        const checkbox = event.currentTarget
        let resourceId, endpoint

        if (checkbox.dataset.driverId) {
            resourceId = checkbox.dataset.driverId
            endpoint = `/drivers/${resourceId}/toggle_active`
        } else if (checkbox.dataset.loadingLocationId) {
            resourceId = checkbox.dataset.loadingLocationId
            endpoint = `/loading_locations/${resourceId}/toggle_active`
        } else {
            console.error("No resource ID found for toggle")
            return
        }

        console.log("Toggling active for resource:", resourceId, "endpoint:", endpoint)

        try {
            const response = await fetch(endpoint, {
                method: "PATCH",
                headers: {
                    "X-CSRF-Token": document.querySelector("[name='csrf-token']").content
                }
            })

            if (!response.ok) {
                console.error("Toggle failed:", response.status)
                checkbox.checked = !checkbox.checked
                alert("Fehler beim Aktualisieren")
            } else {
                console.log("Toggle successful")
            }
        } catch (error) {
            console.error("Toggle active error:", error)
            checkbox.checked = !checkbox.checked
            alert("Fehler beim Aktualisieren")
        }
    }

    // Tour-spezifische Methoden
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
            alert("Fehler beim Aktualisieren")
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
            alert("Fehler beim Aktualisieren")
        }
    }

    fieldTargetConnected(element) {
        element.addEventListener("click", this.editField.bind(this))
    }
}