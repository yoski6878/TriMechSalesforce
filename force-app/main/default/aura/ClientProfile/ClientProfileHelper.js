({
	executeAction: function(component, controllermethod, params, callback) {
        var action = component.get("c." + controllermethod);
        if (params != undefined) {
            action.setParams(params);
        }
        return new Promise(function(resolve, reject) {
            action.setCallback(this, function(response) {
                var state = response.getState();
                if (state === "SUCCESS") {
                    var retVal=response.getReturnValue();
                    resolve(retVal);
                }
                else if (state === "ERROR") {
                    var errors = response.getError();
                    if (errors) {
                        if (errors[0] && errors[0].message) {
                            reject(Error("Error message: " + errors[0].message));
                        }
                    }
                    else {
                        reject(Error("Unknown error"));
                    }
                }
            });
            $A.enqueueAction(action);
        });
	},
    setErrorMessage : function(component, message) {
		component.set("v.hasError", true);
		component.set("v.errorMessage", message);
	}
})