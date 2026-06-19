import { LightningElement } from 'lwc';
import EGG_IMG from '@salesforce/resourceUrl/easterEggImg';

const SECRET_SEQUENCE = [
    'ArrowUp', 'ArrowUp', 'ArrowDown', 'ArrowDown',
    'ArrowLeft', 'ArrowRight', 'ArrowLeft', 'ArrowRight',
    'b', 'a'
];

export default class EasterEggUtility extends LightningElement {
    sequence = [];
    showEgg = false;
    eggImg = EGG_IMG;

    connectedCallback() {
        window.addEventListener('keydown', this.handleKeyDown);
    }

    disconnectedCallback() {
        window.removeEventListener('keydown', this.handleKeyDown);
    }

    handleKeyDown = (event) => {
        this.sequence.push(event.key);
        if (this.sequence.length > SECRET_SEQUENCE.length) {
            this.sequence.shift();
        }
        if (this.sequence.join(',') === SECRET_SEQUENCE.join(',')) {
            this.showEgg = true;
            this.sequence = [];
        }
    };

    handleClose() {
        this.showEgg = false;
    }
}