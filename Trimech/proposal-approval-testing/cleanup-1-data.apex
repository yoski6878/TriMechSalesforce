// Run first. Deletes the ZZ TEST account (its opportunities and proposals go with it) and removes the two test Renewal flags.
delete [SELECT Id FROM Account WHERE Name = 'ZZ TEST Approval Rules Account'];
update new List<Product2>{
    new Product2(Id = '01tPZ000003NdoYYAS', Approval_Trigger__c = null),
    new Product2(Id = '01tPZ000003b25xYAA', Approval_Trigger__c = null)
};
