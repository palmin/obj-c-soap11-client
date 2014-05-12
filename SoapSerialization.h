//
//  SoapSerialization.h
//     Lightweight methods for encoding and decoding SOAP 1.1 envelopes
//     with support for creating a NSURLRequest to perform SOAP requests.
//
// Copyright (c) 2014 Anders Borum
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

#import <Foundation/Foundation.h>

@interface SoapSerialization : NSObject <NSXMLParserDelegate>;

// Create SOAP envelope where Body has the given root element name and namespace
// and where the dictionaryArrayStringOrNumber must be either nil, NSNull, NSNumber,
// NSString, NSArray or a NSDictionary containing elements of these types. Exception
// is thrown if any other kinds of objects appear.
+(NSData *)dataWithSOAPObject:(id)dictionaryStringOrNumber
                         name:(NSString*)name
                    namespace:(NSString*)nspace
                     encoding:(NSStringEncoding)encoding;

// SOAP envelope will be UTF-8 encoded.
+(NSData*)dataWithSOAPObject:(id)dictionaryArrayStringOrNumber
                         name:(NSString*)name
                    namespace:(NSString*)theNamespace;

// Decode Body or Fault part of SOAP envelope returned as NSDictionary containing
// NSArray, NSString or NSDictionary elements. Note that numbers will appear as
// NSString objects but intValue or doubleValue can be used to extract value.
//
// Empty arrays and strings look the same when decoding, and these will be represented
// by objects that answer 0 to both count and length, such that they can be treated as
// either NSString, NSArray or NSDictionary and behave as empty and will respond
// to messages allowed by either of these 3 objects.
//
// Dictionary keys will correspond to element names without namespace prefix.
// It is allowed to let error be NULL if you do not care about error.
// In case of errors nil is always returned.
+(id)SOAPObjectWithData:(NSData *)data error:(NSError**)error;

// Create HTTP POST request for a SOAP 1.1 request to the given endpoint url
// where soapAction can be either relative or absolute and the rules given in
// dataWithSOAPObject:name:namespace applies to dictionaryArrayStringOrNumber
+(NSMutableURLRequest*)requestForSoapEndpoint:(NSURL*)url
                                       object:(id)dictionaryArrayStringOrNumber
                                         name:(NSString*)name
                                       action:(NSString*)soapAction
                                    namespace:(NSString*)nspace;

// identical to requestForSoapEndpoint:object:action:name:namespace:
// where action and name are identical
+(NSMutableURLRequest*)requestForSoapEndpoint:(NSURL*)url
                                       object:(id)dictionaryArrayStringOrNumber
                                         name:(NSString*)name
                                    namespace:(NSString*)nspace;

// identical to requestForSoapEndpoint:object:name:namespace:
// where namespace is derived with endpoint url, such that it is
//  protocol://hostname
+(NSMutableURLRequest*)requestForSoapEndpoint:(NSURL*)url
                                       object:(id)dictionaryArrayStringOrNumber
                                         name:(NSString*)name;

@end
