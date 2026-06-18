@isTest
public class WorkOrderTriggerHandlerTest {

    @isTest
    static void testPreventativeMaintenanceWorkOrder() {

        Account acc = new Account(Name = 'Test Account');
        insert acc;

        Asset asset1 = new Asset(
            Name = 'Asset 1',
            AccountId = acc.Id,
            Status = 'Installed'
        );
        insert asset1;

        Asset asset2 = new Asset(
            Name = 'Asset 2',
            AccountId = acc.Id,
            Status = 'Installed'
        );
        insert asset2;

        WorkType pmWorkType = new WorkType(
            Name = 'Preventative Maintenance',
            EstimatedDuration = 60
        );
        insert pmWorkType;

        WorkOrder wo = new WorkOrder(
            Subject = 'PM Work Order',
            AccountId = acc.Id,
            AssetId = asset1.Id,
            WorkTypeId = pmWorkType.Id,
            Status = 'New',
            StartDate = System.now()
        );

        Test.startTest();
        insert wo;
        wo.StartDate = System.now().addDays(1);
        update wo;
        wo.AssetId = asset2.Id;
        update wo;
        Test.stopTest();
    }
}