/**
 * Lightning Web Component for Flow Screens and Lightning Pages:            fsc_drawLine
 * 
 * This drawLine component is designed to be used on a Flow Screen, Record Page, App Page or Home Page to display a horizontal line
 * Attributes are available for vetical margins, color and thickness.
 * 
 * This component is packaged as part of the unofficialsf.com FlowScreenComponentsBasePack
 * 
 * Additional components packaged with this LWC:
 * 
 *                      Lightning Web Components:       fsc_drawLineCPE
 * 
 * CREATED BY:          Eric Smith
 * 
 * VERSION:             1.0.0
 * 
 * DATE:                4/11/2023
 * 
 * 
**/

import { LightningElement, api } from 'lwc';

export default class Fsc_drawLine extends LightningElement {

    // Component Input Attributes
    @api marginTop;
    @api marginBottom;
    @api thickness;
    @api color;
    @api vCard;

    // Set Defaults
    get classMarginTop() {
        return (this.marginTop) ? this.marginTop : 'none';
    }

    get classMarginBottom() {
        return (this.marginBottom) ? this.marginBottom : 'xx-small';
    }

    get styleThickness() {
        return (this.thickness) ? this.thickness : '1';
    }

    get styleColor() {
        return (this.color) ? this.color : '#808080';
    }

    get sldsClass() {
        return `slds-m-top_${this.classMarginTop} slds-m-bottom_${this.classMarginBottom}`;
    }

    get lineStyle() {
        return `border-width: ${this.styleThickness}px;border-color: ${this.styleColor};`;
    }

    get displayVCard() {
        return (this.vCard === true) ? true : false;
    }

}