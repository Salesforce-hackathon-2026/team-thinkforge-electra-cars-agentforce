import { LightningElement, api, track } from 'lwc';

export default class ElectraSlotPicker extends LightningElement {
    @api slotsData = []; // Passed from parent
    @track selectedDate;

    connectedCallback() {
        if (this.slotsData.length > 0) {
            this.selectedDate = this.slotsData[0].slotDate;
        }
    }

    get days() {
        // Group unique dates from the slots
        const uniqueDates = [...new Set(this.slotsData.map(s => s.slotDate))];
        return uniqueDates.map(d => {
            const dateObj = new Date(d);
            return {
                date: d,
                weekday: dateObj.toLocaleDateString('en-US', { weekday: 'short' }).toUpperCase(),
                dayNum: dateObj.getDate(),
                computedClass: d === this.selectedDate ? 'day-btn active' : 'day-btn'
            };
        });
    }

    get activeSlots() {
        return this.slotsData
            .filter(s => s.slotDate === this.selectedDate)
            .map(s => ({
                time: s.slotTime,
                fullValue: s.displayTime // The string we send back to the Agent
            }));
    }

    handleDayClick(event) {
        this.selectedDate = event.currentTarget.dataset.date;
    }

    handleSlotClick(event) {
        const selection = event.currentTarget.dataset.val;
        console.log('✅ Slot Selected in Child:', selection);
        if (selection) {
            // Notify parent of the selection
            this.dispatchEvent(new CustomEvent('select', { detail: selection }));
        }
        
    }

}
