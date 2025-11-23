import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
    static values = { positionId: String }

    showModal() {
        this.fetchDeliveryData()
    }

    async fetchDeliveryData() {
        try {
            // Ändere die URL auf UnassignedDeliveryItems
            const response = await fetch(`/unassigned_delivery_items/${this.positionIdValue}`, {
                headers: {
                    'Accept': 'application/json',
                    'X-CSRF-Token': document.querySelector('[name="csrf-token"]')?.content
                }
            })

            if (response.ok) {
                const data = await response.json()
                this.createModal(data)
            } else {
                console.error('Failed to fetch delivery data')
            }
        } catch (error) {
            console.error('Error fetching delivery data:', error)
        }
    }

    createModal(deliveryData) {
        const existingModal = document.querySelector('.delivery-modal')
        if (existingModal) existingModal.remove()

        const modal = document.createElement('div')
        modal.className = 'delivery-modal'
        modal.innerHTML = this.buildModalContent(deliveryData)

        document.body.appendChild(modal)

        // Add event listeners
        modal.querySelector('.delivery-modal-close').addEventListener('click', () => this.closeModal())
        modal.querySelector('.btn-secondary').addEventListener('click', () => this.closeModal())
        modal.querySelector('.delivery-form').addEventListener('submit', (e) => this.saveChanges(e))
        modal.addEventListener('click', (e) => {
            if (e.target === modal) this.closeModal()
        })

        // Show modal with animation
        requestAnimationFrame(() => {
            modal.classList.add('show')
        })
    }

    buildVehicleOptions(vehicles, currentVehicle, vehicleOverride) {
        // Wenn ein Override vorhanden ist, nutze diesen als Wert
        const selectedValue = vehicleOverride || ''

        let options = '<option value="">Standard-Fahrzeug verwenden</option>'

        vehicles.forEach(vehicle => {
            const selected = vehicle === selectedValue ? 'selected' : ''
            options += `<option value="${vehicle}" ${selected}>${vehicle}</option>`
        })

        return options
    }

    buildModalContent(data) {
        return `
            <div class="delivery-modal-content">
                <div class="delivery-modal-header">
                    <h3>Lieferposition ${data.liefschnr}-${data.posnr} bearbeiten</h3>
                    <button class="delivery-modal-close" type="button">&times;</button>
                </div>
                
                <form class="delivery-form">
                    <input type="hidden" name="position_id" value="${data.position_id}">
                    
                    <div class="delivery-modal-body">
                        
                        <!-- Kunde (Read-Only) -->
                        <div class="info-section">
                            <h4 class="section-title">👤 Kunde</h4>
                            <div class="section-content">
                                <div class="form-group">
                                    <label>Kundenname</label>
                                    <input type="text" value="${data.customer_name || ''}" readonly class="readonly-field">
                                </div>
                            </div>
                        </div>

                        <!-- Produktdetails (EDITIERBAR) -->
                        <div class="info-section">
                            <h4 class="section-title">📦 Produktdetails</h4>
                            <div class="section-content">
                                <div class="form-group">
                                    <label>Produkt</label>
                                    <input type="text" value="${data.bezeichnung || ''}" readonly class="readonly-field">
                                </div>
                                <div class="form-row">
                                    <div class="form-group">
                                    <label>Menge <span class="required">*</span></label>
                                    <div class="input-with-unit">
                                        <input type="number" 
                                           step="any" 
                                           name="menge" 
                                           value="${data.menge || ''}"
                                           class="editable-field"
                                           required>
                                        <span class="unit-label">${data.einheit || ''}</span>
                                    </div>
                                </div>
                          
                            </div>
                        </div>

                        <!-- Preise (EDITIERBAR) -->
                        <div class="info-section">
                            <h4 class="section-title">💰 Preise</h4>
                            <div class="section-content">
                                <div class="form-row">
                                    <div class="form-group">
                                        <label>Frachtpreis (€)</label>
                                        <input type="number" 
                                               step="any" 
                                               name="freight_price" 
                                               value="${(parseFloat(data.freight_price) || 0).toFixed(2)}"
                                               class="editable-field price-input"
                                               data-price-field>
                                    </div>
                                    <div class="form-group">
                                        <label>Beladepreis (€)</label>
                                        <input type="number" 
                                               step="any" 
                                               name="loading_price" 
                                               value="${(parseFloat(data.loading_price) || 0).toFixed(2)}"
                                               class="editable-field price-input"
                                               data-price-field>
                                    </div>
                                    <div class="form-group">
                                        <label>Entladepreis (€)</label>
                                        <input type="number" 
                                               step="any" 
                                               name="unloading_price" 
                                               value="${(parseFloat(data.unloading_price) || 0).toFixed(2)}"
                                               class="editable-field price-input"
                                               data-price-field>
                                    </div>
                                </div>
                                <div class="total-price-display">
                                    <strong>Gesamtpreis:</strong>
                                    <span id="total-price-value">${this.formatCurrency(data.total_price || 0)}</span>
                                </div>
                            </div>
                        </div>

                        <!-- Termin & Info (EDITIERBAR) -->
                        <div class="info-section">
                            <h4 class="section-title">📅 Planung</h4>
                            <div class="section-content">
                                <div class="form-row">
                                    <div class="form-group">
                                        <label>Geplantes Datum</label>
                                        <input type="date" 
                                               name="planned_date" 
                                               value="${data.planned_date || ''}"
                                               class="editable-field">
                                    </div>
                                    <div class="form-group">
                                        <label>Geplante Uhrzeit</label>
                                        <input type="time" 
                                               name="planned_time" 
                                               value="${data.planned_time || ''}"
                                               class="editable-field">
                                    </div>
                                </div>
                                <div class="form-group">
                                    <label>Planungsnotizen</label>
                                    <textarea name="planning_notes" 
                                              rows="3" 
                                              class="editable-field"
                                              placeholder="Besondere Hinweise zur Lieferung...">${data.planning_notes || ''}</textarea>
                                </div>
                            </div>
                        </div>

                        <!-- Fahrzeug & Transport (EDITIERBAR) -->
                        <div class="info-section">
                            <h4 class="section-title">🚛 Fahrzeug & Transport</h4>
                            <div class="section-content">
                                <div class="form-group">
                                    <label>Standard-Fahrzeug</label>
                                    <input type="text" 
                                           value="${data.vehicle || 'Kein Fahrzeug zugeordnet'}" 
                                           readonly 
                                           class="readonly-field"
                                           title="Das Fahrzeug aus dem Verkaufsauftrag">
                                </div>
                                <div class="form-row">
                                    <div class="form-group">
                                        <label>Kessel</label>
                                        <input type="text" 
                                               name="kessel" 
                                               value="${data.kessel || ''}"
                                               class="editable-field"
                                               placeholder="Kessel-Nummer">
                                    </div>
                                    <div class="form-group">
                                        <label>Abweichendes Fahrzeug</label>
                                        <select name="vehicle_override" class="editable-field">
                                            ${this.buildVehicleOptions(data.vehicles || [], data.vehicle, data.vehicle_override)}
                                        </select>
                                        <small class="form-text">Standard-Fahrzeug verwenden oder anderes wählen</small>
                                    </div>
                                </div>
                            </div>
                        </div>

                        <!-- Adressen -->
                        <div class="info-section">
                            <h4 class="section-title">📍 Adressen</h4>
                            <div class="section-content">
                                <div class="form-group">
                                    <label>Beladestelle (Standard)</label>
                                    <textarea rows="2" 
                                              readonly 
                                              class="readonly-field">${data.loading_address || 'Keine Adresse'}</textarea>
                                    <label style="margin-top: 0.5rem;">Abweichende Beladestelle</label>
                                    <textarea name="loading_address_override" 
                                              rows="3" 
                                              class="editable-field"
                                              placeholder="Optional: Andere Beladestelle eingeben">${data.loading_address_override || ''}</textarea>
                                </div>
                                
                                <div class="form-group">
                                    <label>Entladestelle (Standard)</label>
                                    <textarea rows="2" 
                                              readonly 
                                              class="readonly-field">${data.unloading_address || 'Keine Adresse'}</textarea>
                                    <label style="margin-top: 0.5rem;">Abweichende Entladestelle</label>
                                    <textarea name="unloading_address_override" 
                                              rows="3" 
                                              class="editable-field"
                                              placeholder="Optional: Andere Entladestelle eingeben">${data.unloading_address_override || ''}</textarea>
                                </div>
                            </div>
                        </div>

                        <!-- Kommentare -->
                        <div class="info-section">
                            <h4 class="section-title">💬 Kommentare</h4>
                            <div class="section-content">
                                <div class="form-group">
                                    <label>Kundenkommentar</label>
                                    <textarea name="kund_kommentar" 
                                              rows="2" 
                                              class="editable-field"
                                              placeholder="Kommentar für den Kunden...">${data.kund_kommentar || ''}</textarea>
                                </div>
                                <div class="form-group">
                                    <label>Werkskommentar</label>
                                    <textarea name="werk_kommentar" 
                                              rows="2" 
                                              class="editable-field"
                                              placeholder="Interner Kommentar...">${data.werk_kommentar || ''}</textarea>
                                </div>
                            </div>
                        </div>

                    </div>
                    
                    <div class="delivery-modal-actions">
                        <button type="button" class="btn btn-secondary">Abbrechen</button>
                        <button type="submit" class="btn btn-primary">Änderungen speichern</button>
                    </div>
                </form>
            </div>
        `
    }

    async saveChanges(event) {
        event.preventDefault()

        const form = event.target
        const formData = new FormData(form)
        const positionId = formData.get('position_id')

        // Konvertiere FormData zu Objekt
        const data = {}
        formData.forEach((value, key) => {
            if (key !== 'position_id') {
                data[key] = value
            }
        })

        try {
            const response = await fetch(`/unassigned_delivery_items/${positionId}`, {
                method: 'PATCH',
                headers: {
                    'Content-Type': 'application/json',
                    'Accept': 'application/json',
                    'X-CSRF-Token': document.querySelector('[name="csrf-token"]')?.content
                },
                body: JSON.stringify({ unassigned_delivery_item: data })
            })

            if (response.ok) {
                const result = await response.json()
                this.closeModal()

                // Zeige Success-Message
                this.showSuccessMessage('Änderungen erfolgreich gespeichert!')

                // Optional: Seite neu laden um aktualisierte Daten zu zeigen
                setTimeout(() => window.location.reload(), 1000)
            } else {
                const error = await response.json()
                alert('Fehler beim Speichern: ' + (error.errors?.join(', ') || 'Unbekannter Fehler'))
            }
        } catch (error) {
            console.error('Error saving changes:', error)
            alert('Fehler beim Speichern der Änderungen')
        }
    }

    closeModal() {
        const modal = document.querySelector('.delivery-modal')
        if (modal) {
            modal.classList.remove('show')
            setTimeout(() => modal.remove(), 300)
        }
    }

    showSuccessMessage(message) {
        const toast = document.createElement('div')
        toast.className = 'success-toast'
        toast.textContent = message
        document.body.appendChild(toast)

        setTimeout(() => {
            toast.classList.add('show')
        }, 10)

        setTimeout(() => {
            toast.classList.remove('show')
            setTimeout(() => toast.remove(), 300)
        }, 3000)
    }

    formatCurrency(value) {
        return new Intl.NumberFormat('de-DE', {
            style: 'currency',
            currency: 'EUR'
        }).format(value || 0)
    }
}

// Auto-Update Gesamtpreis beim Ändern der Preisfelder
document.addEventListener('DOMContentLoaded', () => {
    document.addEventListener('input', (e) => {
        if (e.target.hasAttribute('data-price-field')) {
            updateTotalPrice()
        }
    })
})

function updateTotalPrice() {
    const priceFields = document.querySelectorAll('[data-price-field]')
    let total = 0

    priceFields.forEach(field => {
        const value = parseFloat(field.value) || 0
        total += value
    })

    const totalDisplay = document.getElementById('total-price-value')
    if (totalDisplay) {
        totalDisplay.textContent = new Intl.NumberFormat('de-DE', {
            style: 'currency',
            currency: 'EUR'
        }).format(total)
    }
}