({
	init : function(component, event, helper) {
		component.set("v.isSpinner",true);
        var firstParams = {
            "recordId":component.get("v.recordId")
        };
        var sdPromise = helper.executeAction(component,"getQuestionsForAccount",firstParams);
        sdPromise.then(
            $A.getCallback(function(result){
                
                var sectionList = result;
                for(var key in sectionList){
                    sectionList[key].questions.forEach(function(quest){
                        if(quest.Question_Type__c == 'Picklist'){
                            var optionList = quest.Question_Template__r.Picklist_Values__c.split(";");
                            optionList.unshift("");
                            quest.options = optionList;
                        }
                    });
                }
                console.log(sectionList);
                component.set("v.sections",sectionList);
            })
        ).catch(
        	$A.getCallback(function(error){
            	helper.setErrorMessage(component,error.message)
        	})
        ).finally(function() {
            component.set("v.isSpinner",false);
        });
	},
    valueChanged : function(component, event, helper) 
    {
        var unsaved = component.find("unsaved");
        unsaved.setUnsavedChanges(true, { label: 'Client Profile' });
    },
    handleDiscard: function(component, event, helper) {
        //method invoke when user click on save discard button
        var unsaved = component.find("unsaved");
        unsaved.setUnsavedChanges(false);
    },    
    doSave : function(component, event, helper){
        
        var wrappers = component.get("v.sections");
        console.log(wrappers);
        
        component.set("v.isSpinner",true);
        var firstParams = {
            "wrappers":wrappers
        };
        var sdPromise = helper.executeAction(component,"saveAnswers",firstParams);
        sdPromise.then(
            $A.getCallback(function(result){
                
            })
        ).catch(
        	$A.getCallback(function(error){
            	helper.setErrorMessage(component,error.message)
        	})
        ).finally(function() {
            component.set("v.isSpinner",false);
            var unsaved = component.find("unsaved");        
            unsaved.setUnsavedChanges(false);
        });
    }
})