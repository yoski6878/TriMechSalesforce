public with sharing class ListViewLeadConversionController {

    /**This is the list which will be passed to Visualforce Page and in turn passed to Flow from Visualforce**/
    public List < Lead > LstSelectedLeads {
        get;
        set;
    }
    
    public ListViewLeadConversionController(ApexPages.StandardSetController listcontroller) {
      
        Set < Id > leadsSelectedIds = new set < Id > ();
        LstSelectedLeads = new List <lead >();
            
        for (Lead l: (Lead[]) listcontroller.getSelected()) {
            leadsSelectedIds.add(l.id);
        }
        
        /**Querying on the Selected records and fetching fields which are required in Flow **/
        LstSelectedLeads = [select Id
                            from lead where id in: leadsSelectedIds];
    }
}