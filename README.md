obj-c-soap11-client
===================

Lightweight methods for encoding and decoding SOAP 1.1 in Objective-C envelopes and making valid SOAP requests.
Requires Automatic Reference Counting (ARC) and is MIT licensed.

```
A small example testing a SOAP request to service echoing input.
//    NSString* endpoint = @"http://www.SoapClient.com/xml/soapresponder.wsdl";
//    NSDictionary* object = @{@"bstrParam1": @"Hello",
//                             @"bstrParam2": @"World"};
//    NSURLRequest* request = [SoapSerialization requestForSoapEndpoint:[NSURL URLWithString:endpoint]
//                                                               object:object name:@"Method1"
//                                                               action:@"SoapObject" namespace:endpoint];
//
//    [NSURLConnection sendAsynchronousRequest:request queue:[NSOperationQueue mainQueue]
//                           completionHandler:^(NSURLResponse* response, NSData* data, NSError* error) {
//                               NSError* soapError = nil;
//                               NSDictionary* dictionary = [SoapSerialization SOAPObjectWithData:data error:&soapError];
//
//                               // Outputs: { bstrReturn = "Your input parameters are Hello and World"; }
//                               NSLog(@"%@", dictionary != nil ? dictionary : soapError);
//                           }];
```
