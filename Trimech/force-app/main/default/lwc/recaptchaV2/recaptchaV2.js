import { LightningElement, track } from 'lwc';

export default class RecaptchaV2 extends LightningElement {

	@track iframeStyle= 'border:0px;height:74px;';

	get iframeStyleget(){
		console.log('iframeStyle', this.iframeStyle)
		return this.iframeStyle;
	}

	@track isFirstLoad = true;
	@track isUnlocked = false;

	constructor(){
		super();
		//this.navigateTo = 'https://trimech12345--trimechuat.sandbox.my.salesforce-sites.com/apex/recaptchaVfpgae';
		//this.navigateTo = 'https://trimech12345--trimechuat.sandbox.my.site.com/support/apex/recaptchaVfpgae'; // (This will work)
		this.navigateTo = window.location.origin + '/support/apex/recaptchaVfpgae'; //( This will work too)
		//this.navigateTo = '/apex/recaptchaVfpgae';
		

		let self = this;
		//window.addEventListener("message", this.listenForMessage);//add event listener for message that we post in our recaptchaV2 static resource html file.
		//Origin from where message will come to Lightning Component i.e. VF page Origin
		//let vfOrigin = "https://trialplayground-dev-ed--c.ap6.visual.force.com";
		try{
			window.addEventListener("message", function(event) {

				let eventData = event.data;
				console.log(event.origin);
				console.log(JSON.stringify(eventData));
				// if (event.origin !== vfOrigin) {
					
				// }
				if (eventData === "Unlock"){
					self.iframeStyle = 'border:0px;height:74px;';
					self.handleEventCall('Enable');
					self.isUnlocked = true;
				}else if (eventData === "Expired"){
					self.iframeStyle = 'border:0px;height:74px;';
					self.handleEventCall('Expired');
					self.isUnlocked = false;
				}else if (eventData === "Error"){
					self.iframeStyle = 'border:0px;height:74px;';
					self.isUnlocked = false;
					self.handleEventCall('Error');
				}else if(eventData.type == 'get-iframe-pos' && self.isUnlocked == false ){
					self.iframeStyle = 'border:0px;height:500px;';
				}
			//self.isFirstLoad = false;
			}, false);	
		}catch(error){
			console.log('Error');
			console.log(Error);
		}
		

	}

	renderedCallback() {
		try{
			const iframe = this.template.querySelector('iframe');

				if (iframe) {
					// Give iframe some time to load its content
					setTimeout(() => {
						try {
							const iframeDocument = iframe.contentDocument || iframe.contentWindow.document;
							console.log('iframeDocument');
							console.log(iframeDocument);
							// Check if iframeDocument is valid
							if (iframeDocument) {
								const iframeHeight = iframeDocument.documentElement.scrollHeight;
								console.log('iframeDocument.documentElement.offtHeight');
								console.log(iframeDocument.documentElement.offtHeight);
								iframe.style.height = `${iframeHeight}px`;
							}
						} catch (error) {
							// Handle cross-origin or other access issues
							console.error('Error adjusting iframe height:', error);
						}
					}, 1000); // Adjust timeout duration if needed
				}
		}catch(error){
			console.log(error);
		}
	}

	handleEventCall(details){

		console.log('handleEventCall');

		const selectEvent = new CustomEvent('buttonstatus', {
						detail: details
					});
				this.dispatchEvent(selectEvent);

	}


	/*@track navigateTo;

	

	constructor(){

		super();

		this.navigateTo = pageUrl;

		//window.addEventListener("message", this.listenForMessage);//add event listener for message that we post in our recaptchaV2 static resource html file.

		window.addEventListener(
			"message",
			(event) => {
				
				console.log('event.origin',event.origin)
				console.log('event.data',JSON.stringify( event.data))

				
			},
			false,
		);


	}

	

	captchaLoaded(event){

		if(event.target.getAttribute('src') == pageUrl){

			console.log('Google reCAPTCHA is loaded.');

		} 

	}

	

	listenForMessage(message){

		//console.log('pageUrl',JSON.stringify(message))
		console.log('message data1 : ' + JSON.stringify(message.data));//message.data - The object passed from the other window.

		console.log('message origin : ' + message.origin);//message.origin - The origin of the window that sent the message at the time postMessage was called.

		const selectEvent = new CustomEvent('validate', {
				detail: name
			});
		this.dispatchEvent(selectEvent);
	}*/



}