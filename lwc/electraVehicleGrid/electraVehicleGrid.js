import { LightningElement, api, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation'; // 1. Import Navigation
import getCmsFeaturedVehicles from '@salesforce/apex/ElectraCmsController.getCmsFeaturedVehicles';

export default class ElectraVehicleGrid extends NavigationMixin(LightningElement) { // 2. Extend NavigationMixin
    @api cmsCollectionId; 
    vehicles;
    error;

    @wire(getCmsFeaturedVehicles, { collectionKey: '$cmsCollectionId' })
    wiredVehicles({ error, data }) {
        if (data) {
            this.vehicles = data;
            this.error = undefined;
        } else if (error) {
            this.error = error;
            this.vehicles = undefined;
        }
    }

    // 3. The Navigation Handler
    handleExplore(event) {
        // Get the specific CMS ID from the button's data-id attribute
        const vehicleId = event.target.dataset.id;

        // Navigate to the vehicle-detail page with the contentKey in the URL
        this[NavigationMixin.Navigate]({
            type: 'standard__webPage',
            attributes: {
                url: '/vehicle-detail?contentKey=' + vehicleId
            }
        });
    }

    // 4. The Navigation Handler for Book a Test drive
    handleBookTestDrive(event) {
        // Grab the contentKey from the data-key attribute we set in HTML
        const vehicleId = event.target.dataset.id;

        // 1. Define the Page Reference
        /*const pageRef = {
            type: 'standard__webPage',
            attributes: {
                url: '/concierge-agent?contentKey=' + vehicleId
            }
        };*/

        // 1. Use comm__namedPage instead of standard__webPage
        // This automatically handles the "/ElectraCarsWeb/s/" part for you
        const pageRef = {
            type: 'comm__namedPage',
            attributes: {
                name: 'Concierge__c' // Check the API Name in your Experience Builder
            },
            state: {
                // Passing the ID in the state object is cleaner than string concatenation
                contentKey: vehicleId
            }
        };

        // 2. Generate the URL and open in a new window/tab
        this[NavigationMixin.GenerateUrl](pageRef)
            .then(url => {
                window.open(url, '_blank');
            })
            .catch(error => {
                console.error('URL Generation Failed:', error);
            });
    }
}
