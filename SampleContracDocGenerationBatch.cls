/**
 * Created by adharshvlocity on 6/4/18.
 */

public class SampleContracDocGenerationBatch extends DocTemplateMappingAbstractClass
    {
        private Integer lastIndex = 0;
        private String lastLineNumber = '0000';


        private static final String  firstRow = '<table border="1" repeatHeader="true"><tr style="color: #3366ff;background-color: #dbcece;"><td><strong><viawrapper>ItemName</viawrapper></strong></td><td><strong><viawrapper>Quantity</viawrapper></strong></td>'+
        +'<td><strong><viawrapper>MRC</viawrapper></strong></td><td><strong><viawrapper>NRC</viawrapper></strong></td></tr>';
        private static final String  tableRow = '<tr ><td><viawrapper>{Name}</viawrapper></td><td><viawrapper>{Quantity}</viawrapper></td>'+
        +'<td><viawrapper>{MRC}</viawrapper></td><td><viawrapper> {NRC}</viawrapper></td></tr>';
        private static final String tableEndTag = '</table>';
        private static  Integer size = 200;
        private static  Integer Totalsize = 0;
        private static Integer globalCliCounter = 1;
        private Map<Id,String> IdtoItemProcessedMap = new Map<Id,String>();

    /*****************************************************************************************
        This method is repsonsible for generating the HTML table content that needs to be stored on each section
        Note that repeatingMapList holds have the html content per lineitem
        The tableEndTag should only be add at the end of the Batch job for last LineItem
        If the tableEndTag is included in the middle of Batch Job run the word document will have parsing issue
    ******************************************************************************************/
        public override List<Object> getNextSet(String sectionName)
            {
                String ADDEDTOTABLE = 'AddedtoTable';
                List<Object> repeatingMapList = new List<Object>();

                System.debug('ContractID::' +objectId);

                //globalCliCounter is used track the lineitem count that are processed.
                if(paginationOptionsMap.containsKey('globalCliCounter')){
                    globalCliCounter = (Integer)paginationOptionsMap.get('globalCliCounter');
                }
                //IdtoItemProcessedMap contains the items that are processed in firt batch
                if(paginationOptionsMap.containsKey('IdtoItemProcessedMap')){
                    IdtoItemProcessedMap = (Map<Id,String>)paginationOptionsMap.get('IdtoItemProcessedMap');
                }

                List<ContractLineItem__c> cliList = new List<ContractLineItem__c>();
                //Get Total Line Item Count
                for (AggregateResult countResults
                        : [Select Count(id) from ContractLineItem__c where ContractId__c = :objectId] ){
                    Totalsize = integer.valueof(countResults.get('expr0'));
                }
                //IMPT:: Use paginationOptionsMap to access variables across each batch runs
                System.debug('paginationOptionsMap::::'+JSON.serialize(paginationOptionsMap));
                System.debug('TotalLineItemCount::' + Totalsize);
                //Get the List of first Size * Line Items
                if(paginationOptionsMap.get('lastRecord') == null) {
                    for (ContractLineItem__c cli : [Select Id,Name,Product2Id__r.Name,LineNumber__c,
                            Quantity__c, OneTimeTotal__c,
                            OneTimeCharge__c ,RecurringTotal__c
                            from ContractLineItem__c
                            where ContractId__c =: objectId
                    Order by LineNumber__c limit :size]){
                        cliList.add(cli);
                    }
                    paginationOptionsMap.put('firstrow',true);
                }
                // Get the List of Lineitems to be processed for next Consecutive Batch runs
                else if (paginationOptionsMap.get('lastRecord') != null &&
                                String.valueOf(paginationOptionsMap.get('lastSectionName')) == sectionName)
                {
                    //LastIndex is used for setting the section Sequence
                    lastIndex = globalCliCounter;
                    integer countLine = 0;
                    Set<Id> CliIdToQuerySet = IdtoItemProcessedMap.keyset();
                    for (ContractLineItem__c cli : [Select Id,Name,Product2Id__r.Name,LineNumber__c,
                            Quantity__c, OneTimeTotal__c,
                            OneTimeCharge__c ,RecurringTotal__c
                            from ContractLineItem__c
                            where  ContractId__c =: objectId AND Id NOT IN :CliIdToQuerySet
                    Order by Id ]){
                        if(countLine < size) {
                                cliList.add(cli);
                                countLine++;
                        } else if(countLine > size){

                            break;
                        }
                    }
                    System.debug('>>>>>> LintemCount To Iterate::'+countLine);


                }

                paginationOptionsMap.put('lastSectionName',sectionName);
                System.debug('Size::::' + size);
                Boolean breakLoop = false;
                if(cliList != null && !cliList.isEmpty() && cliList.size() > 0) {

                    //Iterate over the the LinItems to Construct the SectionHTML Content
                    for (Integer i = 0; i < cliList.size(); i++)
                        {

                            //String qty = String.valueOf(i);
                            Id Id = cliList[i].Id;
                            String MRC = '$' + cliList[i].RecurringTotal__c;
                            String NRC = '$' + cliList[i].OneTimeTotal__c;

                            String LineNumber = cliList[i].LineNumber__c;
                            String Name = cliList[i].Name;
                            System.debug('>>>LineNumber' + LineNumber);
                            list<string> sl = new list<string>();
                            sl = LineNumber.split('0');

                            String qty =  String.Valueof(cliList[i].Quantity__c);

                            String html = '';
                            // Set Required floags for first Iteration
                            if (i == 0 && paginationOptionsMap.get('firstrow') == true)
                            {
                                html = firstRow;
                                html = html + tableRow.replace('{Name}', Name);
                                html = html.replace('{Quantity}', qty);
                                html = html.replace('{MRC}', MRC);
                                html = html.replace('{NRC}', NRC);
                                paginationOptionsMap.put('firstrow', false);
                                globalCliCounter++;
                                IdtoItemProcessedMap.put(Id, ADDEDTOTABLE);
                            }
                            else if (  globalCliCounter < Totalsize && paginationOptionsMap.get('firstrow') == false )
                            {
                                html = tableRow.replace('{Name}', Name);
                                html = html.replace('{Quantity}', qty);
                                html = html.replace('{MRC}', MRC);
                                html = html.replace('{NRC}', NRC);
                                globalCliCounter++;
                                IdtoItemProcessedMap.put(Id,ADDEDTOTABLE);
                            }
                            //Set Required flags for the last iteration.
                            else if ( globalCliCounter >= Totalsize )
                            {
                                html = tableRow.replace('{Name}', Name);
                                html = html.replace('{Quantity}', qty);
                                html = html.replace('{MRC}', MRC);
                                html = html.replace('{NRC}', NRC);
                                html = html + tableEndTag;
                                globalCliCounter++;
                                IdtoItemProcessedMap.put(Id,ADDEDTOTABLE);
                                breakLoop = true;
                            }

                            paginationOptionsMap.put('lastRecord', LineNumber);
                            paginationOptionsMap.put('lastCli', cliList[i]);
                            repeatingMapList.add(html);
                            if(breakLoop == true)
                                break;
                        }
                    System.debug('globalCliCounter::::' + globalCliCounter);
                    paginationOptionsMap.put('IdtoItemProcessedMap', IdtoItemProcessedMap );
                    paginationOptionsMap.put('globalCliCounter', globalCliCounter );
                }
                return repeatingMapList;
            }

    /*****************************************************************************************
        This method is used by Managed Batch job verify if the current processing required
    ******************************************************************************************/
        public override Boolean hasNextSet(String sectionName)
            {

                Integer lastIndex = 0;
                for (AggregateResult countResults
                        : [Select Count(id) from ContractLineItem__c where ContractId__c =: objectId] ){
                    Totalsize = integer.valueof(countResults.get('expr0'));
                }

                if (paginationOptionsMap.get('globalCliCounter') != null &&
                                String.valueOf(paginationOptionsMap.get('lastSectionName')) == sectionName)
                {
                    globalCliCounter = Integer.valueOf(paginationOptionsMap.get('globalCliCounter'));
                    System.debug('>>>>lastIndex?InsidepaginationOptionsMap >>' + lastIndex);
                }
                Id objId = objectId;
                System.debug('>>>>globalCliCounter?>>' + globalCliCounter);
                System.debug('>>>>Totalsize?>>' + Totalsize);
                System.debug('>>>>Size?>>' + size);

                return (globalCliCounter + 1) < Totalsize;
            }
    /*****************************************************************************************
        This method is used by Managed Package Batch job to identify Section Sequence
    ******************************************************************************************/
        public override Integer getStartIndex()
            {
                return lastIndex;
            }

    /*****************************************************************************************
        This method usually returns the count of number of LineItems
        The count returned here should be > 200 for multiple batch instance to be invoked
    ******************************************************************************************/
        public override Integer getBatchDataCount(String sectionName)
            {
                for (AggregateResult countResults
                        : [Select Count(id) from ContractLineItem__c where ContractId__c = : objectId] ){
                    Totalsize = integer.valueof(countResults.get('expr0'));
                }
                System.debug('>>>>lastIndex?>>' + Totalsize);
                System.debug('>>>>sectionName?>>' + sectionName);
                return Totalsize;

            }

}