
// TO DO: this flow only works currently for contacts. make it work for leads as well.
public class generateAllRandomStrings implements Database.Batchable<sObject> {
  public Integer emailLimits;
  public Integer recordsProcessed = 0;

  @InvocableMethod(
    label='Generate Random Text Strings for All in Batch'
    description='generates a random id for all contacts and leads'
  )
  public static String[] doThing(String[] input) {
    Database.executeBatch(new generateAllRandomStrings());
    return input;
  }

  public Database.QueryLocator start(Database.BatchableContext bc) {
    //,
    //boolean isContact
    //figure out how to make it work for boolean for both sobjects

    return Database.getQueryLocator(
      [
        SELECT Id
        FROM Contact
        WHERE Public_Id__c = NULL
        WITH SECURITY_ENFORCED

      ]
    );
  }

  public void execute(Database.BatchableContext bc, List<Contact> scope) {

    List<Contact> updateCon = new List<Contact>();
    for (Contact c : scope) {
      String algorithmName = 'AES128';
      Blob key = Crypto.generateAesKey(128);
      Blob data = Blob.valueOf(c.Id);
      Blob encrypted = Crypto.encryptWithManagedIV(algorithmName, key, data);
      String encryptedString = EncodingUtil.base64Encode(encrypted);
      String urlEncoded = EncodingUtil.urlEncode(encryptedString, 'UTF-8');
      System.debug('urlencoded:' + urlEncoded);
      System.debug('encryptedString' + encryptedString);
      c.Public_Id__c = urlEncoded;
      updateCon.add(c);

      recordsProcessed = recordsProcessed + 1;
    }
    database.update(updateCon, false);
    System.debug('ContactList:' + updateCon);
  }

  public void finish(Database.BatchableContext bc) {
    //check in trigger if it already exists, if not that is fine
    //in this class check for how many exist now. and let them know how many didnt populate.
    // say run this again if it doesnt work and there is something else going on like validation rulesm, sharing rules, other triggers preventing records from being updated
    AsyncApexJob job = [
      SELECT
        Id,
        Status,
        NumberOfErrors,
        JobItemsProcessed,
        TotalJobItems,
        CreatedBy.Email
      FROM AsyncApexJob
      WHERE Id = :bc.getJobId()
    ];

    String subject = 'Public Ids Added';
    String body =
      'records processed ' +
      recordsProcessed.format() +
      '. The batch apex processed ' +
      job.TotalJobItems;
    // Define the email
    Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
    // Now sets the below paramaters of the email object
    email.setSubject(subject);
    // Here I am accessing current user email id to whom we are sending email
    email.setToAddresses(new List<String>{ UserInfo.getUserEmail() });
    email.setPlainTextBody(body);
    // Sends the email
    Messaging.SendEmailResult[] r = Messaging.sendEmail(
      new List<Messaging.SingleEmailMessage>{ email }
    );
    system.debug('records processed: ' + recordsProcessed);
    emailLimits = Limits.getEmailInvocations();
    system.debug('emaillimits:' + emailLimits);
    if (r[0].success) {
      System.debug(
        'The email was sent successfully to ' + UserInfo.getUserEmail()
      );
    } else {
      System.debug('The email failed to send: ' + r[0].errors[0].message);
      FeedItem post = new FeedItem();
      post.ParentId = UserInfo.getUserId();
      post.Body = body;
      List<FeedItem> postList = new List<FeedItem>();
      postList.add(post);
      insert postList;
    }
  }
}
