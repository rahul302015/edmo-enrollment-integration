import { LightningElement, api, wire } from 'lwc';
import getLatestScore from '@salesforce/apex/EnrollmentScoreController.getLatestScore';

export default class EnrollmentScoreCard extends LightningElement {
    @api recordId;

    scoreData;
    errorMessage;
    isLoaded = false;

    @wire(getLatestScore, { contactId: '$recordId' })
    wiredScore({ data, error }) {
        this.isLoaded = true;

        if (data) {
            this.scoreData = data;
            this.errorMessage = null;
            return;
        }

        if (error) {
            this.scoreData = null;
            this.errorMessage = error?.body?.message || 'Unable to load enrollment score.';
            return;
        }

        this.scoreData = null;
        this.errorMessage = null;
    }

    get hasScore() {
        return !!this.scoreData;
    }

    get showNoScore() {
        return this.isLoaded && !this.scoreData && !this.errorMessage;
    }

    get score() {
        return this.scoreData?.score;
    }

    get recommendedAction() {
        return this.scoreData?.recommendedAction;
    }

    get sourceSystem() {
        return this.scoreData?.sourceSystem;
    }

    get scoredAt() {
        return this.scoreData?.scoredAt;
    }

    get priority() {
        return this.scoreData?.priority;
    }

    get badgeClass() {
        const base = 'badge';
        const priority = (this.priority || '').toLowerCase();
        if (priority === 'hot') {
            return `${base} badge-hot`;
        }
        if (priority === 'warm') {
            return `${base} badge-warm`;
        }
        return `${base} badge-cold`;
    }
}