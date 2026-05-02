import { LightningElement, api } from 'lwc';
import communityPath from '@salesforce/community/basePath';

export default class ElectraHero extends LightningElement {
    @api cmsMediaSource; 
    @api cmsFallbackPoster;
    @api mediaUrl;
    @api fallbackImage;
    @api mediaType = 'video';
    @api showSecondaryCta = false;

    get isVideo() {
        return this.mediaType === 'video';
    }

    get resolvedMediaUrl() {
        return this.formatAuraCmsUrl(this.cmsMediaSource || this.mediaUrl);
    }

    get resolvedFallback() {
        return this.formatAuraCmsUrl(this.cmsFallbackPoster || this.fallbackImage);
    }

    /**
     * ARCHITECT SOLUTION: Builds the required /sfsites/c bridge for Aura sites.
     */
    formatAuraCmsUrl(input) {
        if (!input) return '';
        if (input.startsWith('http')) return input;

        // 1. Extract the Content ID (The MCO... string)
        let contentId = input;
        if (input.includes('/')) {
            const parts = input.split('/');
            contentId = parts[parts.length - 1];
        }

        /**
         * 2. Construct the Aura CMS Bridge:
         * [site-prefix] + /sfsites/c/cms/delivery/media/ + [ID]
         */
        const auraBridge = '/sfsites/c/cms/delivery/media/';
        const fullUrl = `${communityPath}${auraBridge}${contentId}`;
        
        console.log('Final Asset URL:', fullUrl);
        return fullUrl;
    }

    handlePrimaryCTA() {
        window.location.href = communityPath + '/vehicles';
    }

    handleSecondaryCTA() {
        window.location.href = communityPath + '/book-test-drive';
    }
}
