//
//  SoapSerialization.m
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

#if !__has_feature(objc_arc)
# error SoapSerialization requires ARC (Automatic Reference Counting)
#endif

#import "SoapSerialization.h"

#pragma mark EmptySoapInstance

// EmptySoapInstance contains empty NSString, NSDictionary and NSArray
// and will forward messages to the first one supporting a given selector.
@interface EmptySoapInstance : NSObject {
    NSString* string;
    NSDictionary* dictionary;
    NSArray* array;
}
@end;

@implementation EmptySoapInstance

-(id)init {
    self = [super init];
    if(self) {
        string = [NSString new];
        dictionary = [NSDictionary new];
        array = [NSArray new];
    }
    return self;
}

-(BOOL)respondsToSelector:(SEL)aSelector {
    return [string respondsToSelector:aSelector] ||
           [dictionary respondsToSelector:aSelector] ||
           [array respondsToSelector:aSelector];
}

- (NSMethodSignature *)methodSignatureForSelector:(SEL)aSelector {
    if([string respondsToSelector:aSelector]) return [string methodSignatureForSelector:aSelector];
    if([dictionary respondsToSelector:aSelector]) return [dictionary methodSignatureForSelector:aSelector];
    if([array respondsToSelector:aSelector]) return [array methodSignatureForSelector:aSelector];
    
    return [super methodSignatureForSelector:aSelector];
}

- (void)forwardInvocation:(NSInvocation *)invocation {
    SEL aSelector = [invocation selector];
    
    if([string respondsToSelector:aSelector]) {
        [invocation invokeWithTarget:string];
    } else if([dictionary respondsToSelector:aSelector]) {
        [invocation invokeWithTarget:dictionary];
    } else if([array respondsToSelector:aSelector]) {
        [invocation invokeWithTarget:array];
    } else {
        [super forwardInvocation:invocation];
    }
}

-(NSString*)description { return @"<empty>"; }

@end

#pragma mark -

@interface SoapSerialization () {
    NSMutableDictionary* root;
    NSMutableArray* dictionaryStack;
    NSMutableString* currentString;
    
    EmptySoapInstance* empty;
}
@end

@implementation SoapSerialization

// special characters (&<>) and sometimes quotes (") are XML-encoded
static NSString* xmlEscape(NSString* text, BOOL quotes) {
    NSString* encoded = [text stringByReplacingOccurrencesOfString:@"&" withString:@"&amp;"];
    encoded = [encoded stringByReplacingOccurrencesOfString:@"<" withString:@"&lt;"];
    encoded = [encoded stringByReplacingOccurrencesOfString:@">" withString:@"&gt;"];
    if(quotes) {
        encoded = [encoded stringByReplacingOccurrencesOfString:@"\"" withString:@"&quot;"];
    }
    return encoded;
}

// nil (and NSNUll) are just ignored, while NSDictionary is appended recursively inside element where name is
// key from dictionary. Each element for NSArray is output and NSString and NSNumber objects are output with
// their description which will give suitable results. Exception is raised on any other objects kinds.
static void appendObject(NSMutableString* string, NSObject* dictionaryArrayStringOrNumber) {
    if(!dictionaryArrayStringOrNumber || [dictionaryArrayStringOrNumber isKindOfClass:[NSNull class]]) return;
    
    if([dictionaryArrayStringOrNumber isKindOfClass:[NSArray class]]) {
        NSArray* array = (NSArray*)dictionaryArrayStringOrNumber;
        for (NSObject* element in array) {
            appendObject(string, element);
        }
    } else if([dictionaryArrayStringOrNumber isKindOfClass:[NSDictionary class]]) {
        NSDictionary* dict = (NSDictionary*)dictionaryArrayStringOrNumber;
        for (NSString* key in dict) {
            NSObject* value = [dict objectForKey:key];
            if([value isKindOfClass:[NSArray class]]) {
                NSArray* array = (NSArray*)value;
                for (NSObject* element in array) {
                    [string appendFormat:@"<%@>", key];
                    appendObject(string, element);
                    [string appendFormat:@"</%@>", key];
                }
            } else {
                [string appendFormat:@"<%@>", key];
                appendObject(string, value);
                [string appendFormat:@"</%@>", key];
            }
        }
    } else if([dictionaryArrayStringOrNumber isKindOfClass:[NSString class]] ||
              [dictionaryArrayStringOrNumber isKindOfClass:[NSNumber class]]) {
        [string appendString:xmlEscape(dictionaryArrayStringOrNumber.description, NO)];
    } else {
        [NSException raise:@"SOAP serialization failed" format:@"Unable to encode element of %@ kind",
         [dictionaryArrayStringOrNumber class]];
    }
}

+(NSData *)dataWithSOAPObject:(id)dictionaryStringOrNumber
                          name:(NSString*)name
                     namespace:(NSString*)theNamespace
                      encoding:(NSStringEncoding)encoding {
    NSMutableString* string = [NSMutableString string];
    [string appendString:@"<s:Envelope xmlns:s=\"http://schemas.xmlsoap.org/soap/envelope/\"><s:Body xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\" xmlns:xsd=\"http://www.w3.org/2001/XMLSchema\">"];
    
    [string appendFormat:@"<%@ xmlns=\"%@\">", name, xmlEscape(theNamespace, YES)];
    appendObject(string, dictionaryStringOrNumber);
    [string appendFormat: @"</%@></s:Body></s:Envelope>", name];
        
    return [string dataUsingEncoding:encoding];
}

+(NSData *)dataWithSOAPObject:(id)dictionaryStringOrNumber
                         name:(NSString*)name
                    namespace:(NSString*)theNamespace {
    return [self dataWithSOAPObject:dictionaryStringOrNumber name:name
                          namespace:theNamespace encoding:NSUTF8StringEncoding];
}

+(NSMutableURLRequest*)requestForSoapEndpoint:(NSURL*)url
                                       object:(id)dictionaryStringOrNumber
                                         name:(NSString*)name
                                       action:(NSString*)soapAction
                                    namespace:(NSString*)theNamespace {
    NSData* data = [self dataWithSOAPObject:dictionaryStringOrNumber
                                       name:name namespace:theNamespace];
    
    NSURL* actionURL = [NSURL URLWithString:soapAction];
    if(actionURL.scheme.length == 0) {
        actionURL = [[url URLByDeletingLastPathComponent] URLByAppendingPathComponent:soapAction];
    }
    
    NSMutableURLRequest* request = [NSMutableURLRequest requestWithURL:url];
    [request setCachePolicy:NSURLRequestReloadIgnoringCacheData];
    [request setValue:[NSString stringWithFormat:@"\"%@\"", actionURL.absoluteString] forHTTPHeaderField:@"SOAPAction"];
    [request setValue:@"text/xml; charset=utf-8" forHTTPHeaderField:@"Content-Type"];
    [request setValue:[NSString stringWithFormat:@"%lu", (unsigned long)data.length] forHTTPHeaderField:@"Content-Length"];
    [request setHTTPBody:data];
    [request setHTTPMethod:@"POST"];
    
    return request;
}

+(NSMutableURLRequest*)requestForSoapEndpoint:(NSURL*)url
                                       object:(id)dictionaryStringOrNumber
                                         name:(NSString*)name
                                    namespace:(NSString*)theNamespace {
    return [self requestForSoapEndpoint:url object:dictionaryStringOrNumber
                                   name:name action:name namespace:theNamespace];
}

+(NSMutableURLRequest*)requestForSoapEndpoint:(NSURL*)url
                                       object:(id)dictionaryStringOrNumber
                                         name:(NSString*)name {
    NSString* nspace = [NSString stringWithFormat:@"%@://%@", url.scheme, url.host];
    return [self requestForSoapEndpoint:url object:dictionaryStringOrNumber
                                   name:name namespace:nspace];
}

+(id)SOAPObjectWithData:(NSData *)data error:(NSError **)error {
    SoapSerialization* object = [SoapSerialization new];
    object->empty = [EmptySoapInstance new];
        
    NSXMLParser* parser = [[NSXMLParser alloc] initWithData:data];
    parser.delegate = object;
    [parser parse];
    
    if(error && parser.parserError) {
        *error = parser.parserError;
        return nil;
    }
    NSDictionary* response = object->root;
    
    // check for SOAP errors
    NSDictionary* fault = [response objectForKey:@"Fault"];
    if(fault.count > 0) {
        if(error) {
            NSString* reason = [fault objectForKey:@"faultstring"];
            if(reason.length == 0) reason = fault.description;
            NSDictionary* userInfo = @{NSLocalizedDescriptionKey: reason};
            
            int code = 0;
            NSString* faultcode = [fault objectForKey:@"faultcode"];
            if([faultcode respondsToSelector:@selector(intValue)]) {
                code = [faultcode intValue];
            }
            if(!code) code = -1;
            
            *error = [NSError errorWithDomain:@"SOAP Fault" code:code userInfo:userInfo];
        }
        return nil;
    }
    
    // when there is no error we go in one level, as there is always result-wrapper
    if(response.count == 1) {
        //NSLog(@"text = %@\nresponse = %@",
        //      [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding],
        //      response.allValues.firstObject);
        return response.allValues.firstObject;
    }
    
    return response;
}

// for elementNames such as ns:name we return just name,
// and if their is no prefix the name itself is returned.
static NSString* unqualifiedName(NSString* name) {
    NSRange range = [name rangeOfString:@":"];
    if(range.length == 0) return name;
    
    return [name substringFromIndex:range.location + 1];
}

#pragma mark NSXMLParserDelegate

- (void)parser:(NSXMLParser *)parser didStartElement:(NSString *)elementName
  namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName
    attributes:(NSDictionary *)attributeDict {

    NSString* name = unqualifiedName(elementName);
    if(dictionaryStack) {
        currentString = nil;
        
        NSMutableDictionary* last = dictionaryStack.lastObject;
        NSMutableDictionary* inner = [NSMutableDictionary new];
        [dictionaryStack addObject:inner];
        
        // if we already have element with the same name, we replace with array or add to existing array
        NSObject* previous = [last objectForKey:name];
        if(previous) {
            NSMutableArray* array;
            if([previous isKindOfClass:[NSMutableArray class]]) {
                array = (NSMutableArray*)previous;
            } else {
                array = [NSMutableArray arrayWithObject: previous];
                [last setObject:array forKey:name];
            }
            [array addObject:inner];
        } else {
            [last setObject:inner forKey:name];
        }
    }
    
    // start processing with first Body element
    if(dictionaryStack == nil && [name isEqualToString:@"Body"]) {
        root = [NSMutableDictionary new];
        dictionaryStack = [NSMutableArray arrayWithObject:root];
    }
}

-(void)parser:(NSXMLParser *)parser didEndElement:(NSString *)elementName
 namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName {
    [dictionaryStack removeLastObject];

    NSString* name = unqualifiedName(elementName);
    
    if(currentString) {
        NSString* trimmed = [currentString stringByTrimmingCharactersInSet: [NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if(trimmed.length > 0) {
            NSMutableDictionary* last = dictionaryStack.lastObject;
            [last setObject:currentString forKey:name];
            currentString = nil;
        }
    }
    
    // we convert empty dictionary to EmptySoapInstance
    NSMutableDictionary* last = dictionaryStack.lastObject;
    id current = [last objectForKey:name];
    if([current isKindOfClass:[NSMutableDictionary class]] && [current count] == 0) {
        [last setObject:empty forKey:name];
    } else if([current isKindOfClass:[NSMutableArray class]]) {
        if([current count] == 0) {
            [last setObject:empty forKey:name];
        } else {
            id current2 = [current lastObject];
            if([current2 isKindOfClass:[NSMutableDictionary class]] && [current2 count] == 0) {
                [current replaceObjectAtIndex:[current count]-1 withObject:empty];
            }
        }
    }

}

- (void)parser:(NSXMLParser *)parser foundCharacters:(NSString *)string {
    if(!currentString) currentString = [NSMutableString new];
    [currentString appendString:string];
}

- (void)parser:(NSXMLParser *)parser foundCDATA:(NSData *)CDATABlock {
    if(!currentString) currentString = [NSMutableString new];
    
    NSString* string = [[NSString alloc] initWithData:CDATABlock encoding:NSUTF8StringEncoding];
    [currentString appendString:string];
}

#pragma mark -

@end
