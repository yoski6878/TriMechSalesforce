/**
 * ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
 * Class Name      : PandaDocAttachScheduler
 * Author          : <YourName>
 * Created Date    : May 14, 2026
 * Description     : Scheduled class that fires PandaDocAttachBatch every
 *                   15 minutes. Runs as an internal scheduled user so
 *                   ContentVersion DML always succeeds.
 *
 *                   SCHEDULE VIA ANONYMOUS APEX (run once to set up all 4):
 *                   System.schedule('PandaDoc Attach 0',  '0 0  * * * ?', new PandaDocAttachScheduler());
 *                   System.schedule('PandaDoc Attach 15', '0 15 * * * ?', new PandaDocAttachScheduler());
 *                   System.schedule('PandaDoc Attach 30', '0 30 * * * ?', new PandaDocAttachScheduler());
 *                   System.schedule('PandaDoc Attach 45', '0 45 * * * ?', new PandaDocAttachScheduler());
 *
 * Change History  :
 *  Date          │   Author     │   Change
 * ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
 *  May 14, 2026  │ <YourName>   │ Initial version
 * ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
 */
global without sharing class PandaDocAttachScheduler implements Schedulable {

    global void execute(SchedulableContext sc) {
        System.debug('[PandaDocAttachScheduler] Firing PandaDocAttachBatch at ' + System.now());
        Database.executeBatch(new PandaDocAttachBatch(), 1);
    }
}