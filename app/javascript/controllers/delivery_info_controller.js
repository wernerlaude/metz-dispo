import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
    static values = { positionId: String }

    showModal() {
        this.fetchDeliveryData()
    }

    async fetchDeliveryData() {
        try {
            const response = await fetch(`/unassigned_delivery_items/${this.positionIdValue}`, {
                headers: {
                    'Accept': 'application/json',
                    'X-CSRF-Token': document.querySelector('[name="csrf-token"]')?.content
                }
            })

            if (response.ok) {
                const data = await response.json()
                this.currentData = data  // Speichere für Gewichtsberechnung
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

        // Menge-Input Event Listener für Gewichtsberechnung
        const mengeInput = modal.querySelector('input[name="menge"]')
        if (mengeInput) {
            mengeInput.addEventListener('input', (e) => this.updateCalculatedWeight(e))
        }

        // Show modal with animation
        requestAnimationFrame(() => {
            modal.classList.add('show')
        })
    }

    // Gewichtsberechnung basierend auf Einheit (wie im Ruby Model)
    calculateWeight(menge, einheit, typ) {
        if (!menge || !einheit) return 0

        const unit = String(einheit).toUpperCase()
        const quantity = parseFloat(menge) || 0

        switch (unit) {
            case 'T':
            case 'TO':
                return quantity * 1000
            case 'KG':
                return quantity
            case 'SACK':
                return quantity * 25
            case 'BB':
                return quantity * 600
            case 'M³':
            case 'M3':
            case 'CBM':
                return typ === 1 ? quantity * 600 : quantity * 800
            default:
                return 0
        }
    }

    updateCalculatedWeight(event) {
        const menge = parseFloat(event.target.value) || 0
        const einheit = this.currentData?.einheit || ''
        const typ = this.currentData?.typ || 0

        const calculatedWeight = this.calculateWeight(menge, einheit, typ)

        const weightDisplay = document.getElementById('weight-display')
        if (weightDisplay) {
            weightDisplay.value = calculatedWeight.toFixed(2) + ' kg'
        }
    }

    buildVehicleOptions(vehicles, currentLkwnr) {
        let options = '<option value="">Kein Fahrzeug</option>'

        vehicles.forEach(vehicle => {
            const vehicleNumber = vehicle.vehicle_number || ''
            const licensePlate = vehicle.license_plate || ''
            const vehicleShort = vehicle.vehicle_short || ''

            let displayText = licensePlate
            if (vehicleShort) {
                displayText += ` (${vehicleShort})`
            }

            const selected = (String(vehicleNumber) === String(currentLkwnr)) ? 'selected' : ''
            options += `<option value="${vehicleNumber}" ${selected}>${displayText}</option>`
        })

        return options
    }

    buildModalContent(data) {
        // Berechne initiales Gewicht
        const initialWeight = parseFloat(data.gewicht) || parseFloat(data.ladungsgewicht) || this.calculateWeight(data.menge, data.einheit, data.typ) || 0

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
                                ${data.bestnrkd ? `
                                <div class="form-group">
                                    <label>Bestellnummer Kunde</label>
                                    <input type="text" value="${data.bestnrkd}" readonly class="readonly-field">
                                </div>
                                ` : ''}
                                ${data.objekt ? `
                                <div class="form-group">
                                    <label>Projekt/Objekt</label>
                                    <input type="text" value="${data.objekt}" readonly class="readonly-field">
                                </div>
                                ` : ''}
                            </div>
                        </div>

                        <!-- Produktdetails (EDITIERBAR) -->
                        <div class="info-section">
                            <h4 class="section-title">📦 Produktdetails</h4>
                            <div class="section-content">
                                <div class="form-group">
                                    <label>Produkt</label>
                                    <input type="text" value="${data.bezeichn1 || ''}" readonly class="readonly-field">
                                    ${data.bezeichn2 ? `<input type="text" value="${data.bezeichn2}" readonly class="readonly-field" style="margin-top: 0.25rem;">` : ''}
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
                                    <div class="form-group">
                                        <label>Gewicht</label>
                                        <input type="text" 
                                               id="weight-display"
                                               value="${initialWeight.toFixed(2)} kg" 
                                               readonly 
                                               class="readonly-field">
                                    </div>
                                </div>
                            </div>
                        </div>

                        <!-- Preis (Read-Only aus WWS) -->
                        <div class="info-section">
                            <h4 class="section-title">💰 Preis</h4>
                            <div class="section-content">
                                <div class="form-row">
                                    <div class="form-group">
                                        <label>Einzelpreis (netto)</label>
                                        <input type="text" 
                                               value="${this.formatCurrency(data.netto || 0)}"
                                               readonly 
                                               class="readonly-field">
                                    </div>
                                    <div class="form-group">
                                        <label>Gesamtpreis</label>
                                        <input type="text" 
                                               value="${this.formatCurrency((parseFloat(data.menge) || 0) * (parseFloat(data.netto) || 0))}"
                                               readonly 
                                               class="readonly-field">
                                    </div>
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
                                               value="${data.planned_time || data.uhrzeit || ''}"
                                               class="editable-field">
                                    </div>
                                </div>
                                <div class="form-group">
                                    <label>Planungsnotizen</label>
                                    <textarea name="planning_notes" 
                                              rows="2" 
                                              class="editable-field"
                                              placeholder="Notizen zur Planung...">${data.planning_notes || ''}</textarea>
                                </div>
                            </div>
                        </div>

                        <!-- Fahrzeug -->
                        <div class="info-section">
                            <h4 class="section-title">🚛 Fahrzeug</h4>
                            <div class="section-content">
                                <div class="form-group">
                                    <label>Fahrzeug</label>
                                    <select name="lkwnr" class="editable-field">
                                        ${this.buildVehicleOptions(data.vehicles || [], data.lkwnr)}
                                    </select>
                                </div>
                                <div class="form-group">
                                    <label>Kessel</label>
                                    <input type="text" 
                                           name="kessel" 
                                           value="${data.kessel || ''}"
                                           class="editable-field"
                                           placeholder="Kessel-Nummer...">
                                </div>
                            </div>
                        </div>

                        <!-- Adressen (Read-Only) -->
                        <div class="info-section">
                            <h4 class="section-title">📍 Adressen</h4>
                            <div class="section-content">
                                <div class="form-group">
                                    <label>Beladestelle</label>
                                    <textarea rows="2" 
                                              readonly 
                                              class="readonly-field">${data.loading_address || data.ladeort || 'Keine Ladeadresse'}</textarea>
                                </div>
                                
                                <div class="form-group">
                                    <label>Entladestelle</label>
                                    <textarea rows="2" 
                                              readonly 
                                              class="readonly-field">${data.delivery_address || 'Keine Lieferadresse'}</textarea>
                                </div>
                            </div>
                        </div>

                        <!-- Infotexte aus Auftrag (Read-Only) -->
                        ${(data.infoallgemein || data.infoverladung || data.liefertext) ? `
                        <div class="info-section">
                            <h4 class="section-title">📋 Auftragsinformationen</h4>
                            <div class="section-content">
                                ${data.infoallgemein ? `
                                <div class="form-group">
                                    <label>Allgemeine Info</label>
                                    <textarea rows="2" readonly class="readonly-field">${data.infoallgemein}</textarea>
                                </div>
                                ` : ''}
                                ${data.infoverladung ? `
                                <div class="form-group">
                                    <label>Verlade-Info</label>
                                    <textarea rows="2" readonly class="readonly-field">${data.infoverladung}</textarea>
                                </div>
                                ` : ''}
                                ${data.liefertext ? `
                                <div class="form-group">
                                    <label>Liefertext</label>
                                    <textarea rows="2" readonly class="readonly-field">${data.liefertext}</textarea>
                                </div>
                                ` : ''}
                            </div>
                        </div>
                        ` : ''}

                        <!-- Kommentare (EDITIERBAR) -->
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