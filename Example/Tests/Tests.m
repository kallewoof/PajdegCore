//
//  Tests.m
//  Tests
//
//  Created by Kalle Alm on 07/25/2014.
//  Copyright (c) 2014 Kalle Alm. All rights reserved.
//

#include "Pajdeg.h"
#include "PDStreamFilter.h"
#include "PDCatalog.h"
#include "pd_stack.h"
#include "pd_internal.h"
#include "pd_pdf_implementation.h"
#include "pd_md5.h"
#include "pd_crypto.h"
#include "PDPage.h"
#include "PDArray.h"
#include "PDString.h"
#include "PDDictionary.h"
#include "PDNumber.h"

#define PIPE_FILE_IN_BASE  @"test123"
#define PIPE_FILE_OUT_BASE @"test123_out"

#define PIPE_FILE_IN   PIPE_FILE_IN_BASE  ".pdf"
#define PIPE_FILE_OUT  PIPE_FILE_OUT_BASE ".pdf"

SpecBegin(Pajdeg)

//NSFileManager *_fm = [NSFileManager defaultManager];
__block PDPipeRef _pipe;
//__block char *buf_in, *buf_out;
//__block PDInteger len_in, len_out;

pd_pdf_implementation_use();

afterAll(^{
    if (_pipe) {
        PDRelease(_pipe);
        _pipe = nil;
    }
    pd_pdf_implementation_discard();
});

describe(@"MD5 implementation", ^{
    // "The quick brown fox jumps over the lazy dog"
    // 9e107d9d372bb6826bd81d3542a419d6
    
    int i;
    char *key = "The quick brown fox jumps over the lazy dog";
    const char md [] = {0x9e, 0x10, 0x7d, 0x9d, 0x37, 0x2b, 0xb6, 0x82, 0x6b, 0xd8, 0x1d, 0x35, 0x42, 0xa4, 0x19, 0xd6};
    char *res = malloc(16);
    
    pd_md5((unsigned char *)key, (unsigned int)strlen(key), (unsigned char *)res);
    
    i = memcmp(res, md, 16);
    it(@"should work", ^{
        expect(i).to.equal(0);
    });
});

describe(@"RC4 implementation", ^{
    extern void pd_crypto_rc4(pd_crypto crypto, const char *key, int keylen, char *data, long datalen);
    
    it(@"should encrypt correctly", ^{
        const char *key = "Key";
        const char *pt = "Plaintext";
        const char ct [] = {0xBB, 0xF3, 0x16, 0xE8, 0xD9, 0x40, 0xAF, 0x0A, 0xD3};
        char buf[128];
        int i;
        strcpy(buf, pt);
        // Key, Plaintext -> ct
        pd_crypto_rc4(NULL, key, (unsigned int)strlen(key), buf, strlen(pt));
        
        i = strncmp(buf, ct, strlen(pt));
        expect(i).to.equal(0); //encryption failure
        
        // Key, CT -> Plaintext (using result from previous RC4 exec)
        pd_crypto_rc4(NULL, key, (unsigned int)strlen(key), buf, strlen(pt));
        i = strncmp(buf, pt, strlen(pt));
        expect(i).to.equal(0); //decryption failure (from results of encryption)");
        
        memcpy(buf, ct, strlen(pt));
        pd_crypto_rc4(NULL, key, (unsigned int)strlen(key), buf, strlen(pt));
        i = strncmp(buf, pt, strlen(pt));
        expect(i).to.equal(0); //decryption failure (from correct value (ct))");
    });
});

describe(@"object arrays", ^{
    pd_stack defs = NULL;
    PDScannerRef scanner = PDScannerCreateWithState(arbStream);
    __block char *buf = malloc(1024);
    __block PDObjectRef object;
    char *sbuf = "[ 0 1 ]\n";
    PDScannerAttachFixedSizeBuffer(scanner, sbuf, strlen(sbuf));
    XCTAssertTrue(PDScannerPopStack(scanner, &defs), @"Scanner pop stack failed");
    PDRelease(scanner);

    it(@"should construct correctly", ^{
        
        object = PDObjectCreateFromDefinitionsStack(1, defs);
        expect(object).toNot.beNil();
        expect(PDArrayGetCount(PDObjectGetArray(object))).to.equal(2);
        
    });
    
    it(@"should have 0, 1 as its entries", ^{
        PDNumberRef num = PDArrayGetElement(PDObjectGetArray(object), 0);
        expect(num).toNot.beNil();
        expect(PDNumberGetInteger(num)).to.equal(0);
        num = PDArrayGetElement(PDObjectGetArray(object), 1);
        expect(num).toNot.beNil();
        expect(PDNumberGetInteger(num)).to.equal(1);
    });
    
    it(@"should delete last item correctly", ^{
        PDArrayDeleteAtIndex(PDObjectGetArray(object), 1);
        expect(PDArrayGetCount(PDObjectGetArray(object))).to.equal(1);
        PDNumberRef num = PDArrayGetElement(PDObjectGetArray(object), 0);
        expect(num).toNot.beNil();
        expect(PDNumberGetInteger(num)).to.equal(0);
    });
    
    it(@"should append correctly", ^{
        PDArrayAppend(PDObjectGetArray(object), PDStringWithCString(strdup("test")));
        expect(PDArrayGetCount(PDObjectGetArray(object))).to.equal(2);
        PDObjectGenerateDefinition(object, &buf, 1024);
        expect(strcmp(buf, "1 0 obj\n[ 0 (test) ]\n")).to.equal(0);
        PDNumberRef num = PDArrayGetElement(PDObjectGetArray(object), 0);
        expect(num).toNot.beNil();
        expect(PDNumberGetInteger(num)).to.equal(0);
        PDStringRef str = PDArrayGetElement(PDObjectGetArray(object), 1);
        expect(str).toNot.beNil();
        expect(PDStringEqualsCString(str, "test")).to.beTruthy();
    });
    
    it(@"should append twice correctly", ^{
        
        PDArrayAppend(PDObjectGetArray(object), PDStringWithCString(strdup("test2")));
        expect(PDArrayGetCount(PDObjectGetArray(object))).to.equal(3);
        PDObjectGenerateDefinition(object, &buf, 1024);
        expect(strcmp(buf, "1 0 obj\n[ 0 (test) (test2) ]\n")).to.equal(0);
        PDNumberRef num = PDArrayGetElement(PDObjectGetArray(object), 0);
        expect(num).toNot.beNil();
        expect(PDNumberGetInteger(num)).to.equal(0);
        PDStringRef str = PDArrayGetElement(PDObjectGetArray(object), 1);
        expect(str).toNot.beNil();
        expect(PDStringEqualsCString(str, "test")).to.beTruthy();
        str = PDArrayGetElement(PDObjectGetArray(object), 2);
        expect(str).toNot.beNil();
        expect(PDStringEqualsCString(str, "test2")).to.beTruthy();
        
    });
    
    it(@"should delete first item correctly", ^{
        
        PDArrayDeleteAtIndex(PDObjectGetArray(object), 0);
        expect(PDArrayGetCount(PDObjectGetArray(object))).to.equal(2);
        PDObjectGenerateDefinition(object, &buf, 1024);
        expect(strcmp(buf, "1 0 obj\n[ (test) (test2) ]\n")).to.equal(0);
        PDStringRef str = PDArrayGetElement(PDObjectGetArray(object), 0);
        expect(str).toNot.beNil();
        expect(PDStringEqualsCString(str, "test")).to.beTruthy();
        str = PDArrayGetElement(PDObjectGetArray(object), 1);
        expect(str).toNot.beNil();
        expect(PDStringEqualsCString(str, "test2")).to.beTruthy();
        
    });
    
    it(@"should replace correctly", ^{
        
        PDArrayReplaceAtIndex(PDObjectGetArray(object), 1, PDStringWithCString(strdup("test3")));
        expect(PDArrayGetCount(PDObjectGetArray(object))).to.equal(2);
        PDObjectGenerateDefinition(object, &buf, 1024);
        expect(strcmp(buf, "1 0 obj\n[ (test) (test3) ]\n")).to.equal(0);
        PDStringRef str = PDArrayGetElement(PDObjectGetArray(object), 0);
        expect(str).toNot.beNil();
        expect(PDStringEqualsCString(str, "test"), @"string invalid");
        str = PDArrayGetElement(PDObjectGetArray(object), 1);
        expect(str).toNot.beNil();
        expect(PDStringEqualsCString(str, "test3")).to.beTruthy();
        
    });
    
    afterAll(^{
        free(buf);
        PDRelease(object);
    });
});

describe(@"object dicts", ^{
    __block char *buf = malloc(1024);
    __block PDObjectRef object;
    __block PDNumberRef num;
//    __block PDStringRef str;
    
    pd_stack defs = NULL;
    PDScannerRef scanner = PDScannerCreateWithState(arbStream);
    char *sbuf = "<< /Foo 1 /Bar 2 >>\n";
    PDScannerAttachFixedSizeBuffer(scanner, sbuf, strlen(sbuf));
    XCTAssertTrue(PDScannerPopStack(scanner, &defs), @"Scanner pop stack failed");
    PDRelease(scanner);

    it(@"should construct correctly", ^{
        
        object = PDObjectCreateFromDefinitionsStack(1, defs);
        expect(object).toNot.beNil();
        expect(PDDictionaryGetCount(PDObjectGetDictionary(object))).to.equal(2);
        
    });

    it(@"should have the appropriate entries", ^{
        num = PDDictionaryGetEntry(PDObjectGetDictionary(object), "Foo");
        expect(num).toNot.beNil();
        expect(PDNumberGetInteger(num)).to.equal(1);
        num = PDDictionaryGetEntry(PDObjectGetDictionary(object), "Bar");
        expect(num).toNot.beNil();
        expect(PDNumberGetInteger(num)).to.equal(2);
    });

    it(@"should delete correctly", ^{
        
        PDDictionaryDeleteEntry(PDObjectGetDictionary(object), "Bar");
        expect(PDDictionaryGetCount(PDObjectGetDictionary(object))).to.equal(1);
        num = PDDictionaryGetEntry(PDObjectGetDictionary(object), "Foo");
        expect(num).toNot.beNil();
        expect(PDNumberGetInteger(num)).to.equal(1);
        num = PDDictionaryGetEntry(PDObjectGetDictionary(object), "Bar");
        expect(num).to.beNil();
        
    });
        
    /*PDDictionarySetEntry(PDObjectGetDictionary(object), "Zoo", [@[@(1),@(2),@(3)] PDValue]);
    XCTAssertTrue(2 == PDDictionaryGetCount(PDObjectGetDictionary(object)), @"object dict count invalid");
    PDObjectGenerateDefinition(object, &buf, 1024);
    XCTAssertTrue(0 == strcmp(buf, "1 0 obj\n<< /Foo 1 /Zoo [ 1 2 3 ] >>\n"), @"object definition invalid");
    num = PDDictionaryGetEntry(PDObjectGetDictionary(object), "Foo");//PDArrayGetElement(PDObjectGetArray(object), 0);
    XCTAssertNotNull(num, @"null num in dictionary");
    XCTAssertTrue(1 == PDNumberGetInteger(num), @"num invalid");
    PDArrayRef arr = PDDictionaryGetEntry(PDObjectGetDictionary(object), "Zoo");//PDArrayGetElement(PDObjectGetArray(object), 1);
    XCTAssertNotNull(arr, @"null array");
    XCTAssertTrue(3 == PDArrayGetCount(arr), @"array invalid");
    XCTAssertTrue(1 == PDNumberGetInteger(PDArrayGetElement(arr, 0)), @"array invalid");
    XCTAssertTrue(2 == PDNumberGetInteger(PDArrayGetElement(arr, 1)), @"array invalid");
    XCTAssertTrue(3 == PDNumberGetInteger(PDArrayGetElement(arr, 2)), @"array invalid");
    num = PDDictionaryGetEntry(PDObjectGetDictionary(object), "Bar");//PDArrayGetElement(PDObjectGetArray(object), 1);
    XCTAssertTrue(NULL == num, @"value for /Bar should be NULL as it was deleted");
    
    PDDictionarySetEntry(PDObjectGetDictionary(object), "Far", PDAutorelease(PDStringCreateWithName(strdup("Name"))));
    XCTAssertTrue(3 == PDDictionaryGetCount(PDObjectGetDictionary(object)), @"object dict count invalid");
    PDObjectGenerateDefinition(object, &buf, 1024);
    XCTAssertTrue(0 == strcmp(buf, "1 0 obj\n<< /Foo 1 /Zoo [ 1 2 3 ] /Far /Name >>\n"), @"object definition invalid");
    num = PDDictionaryGetEntry(PDObjectGetDictionary(object), "Foo");//PDArrayGetElement(PDObjectGetArray(object), 0);
    XCTAssertNotNull(num, @"null num in dict");
    XCTAssertTrue(1 == PDNumberGetInteger(num), @"num invalid");
    arr = PDDictionaryGetEntry(PDObjectGetDictionary(object), "Zoo");//PDArrayGetElement(PDObjectGetArray(object), 1);
    XCTAssertNotNull(arr, @"null array");
    XCTAssertTrue(3 == PDArrayGetCount(arr), @"array invalid");
    XCTAssertTrue(1 == PDNumberGetInteger(PDArrayGetElement(arr, 0)), @"array invalid");
    XCTAssertTrue(2 == PDNumberGetInteger(PDArrayGetElement(arr, 1)), @"array invalid");
    XCTAssertTrue(3 == PDNumberGetInteger(PDArrayGetElement(arr, 2)), @"array invalid");
    PDStringRef str = PDDictionaryGetEntry(PDObjectGetDictionary(object), "Far");// PDArrayGetElement(PDObjectGetArray(object), 2);
    XCTAssertNotNull(str, @"null string in dict");
    XCTAssertTrue(PDStringEqualsCString(str, "/Name"), @"string invalid");
    num = PDDictionaryGetEntry(PDObjectGetDictionary(object), "Bar");//PDArrayGetElement(PDObjectGetArray(object), 1);
    XCTAssertTrue(NULL == num, @"value for /Bar should be NULL as it was deleted");
    
    PDDictionaryDeleteEntry(PDObjectGetDictionary(object), "Foo");
    XCTAssertTrue(2 == PDDictionaryGetCount(PDObjectGetDictionary(object)), @"object dict count invalid");
    PDObjectGenerateDefinition(object, &buf, 1024);
    XCTAssertTrue(0 == strcmp(buf, "1 0 obj\n<< /Zoo [ 1 2 3 ] /Far /Name >>\n"), @"object definition invalid");
    arr = PDDictionaryGetEntry(PDObjectGetDictionary(object), "Zoo");//PDArrayGetElement(PDObjectGetArray(object), 0);
    XCTAssertNotNull(arr, @"null array");
    XCTAssertTrue(3 == PDArrayGetCount(arr), @"array invalid");
    XCTAssertTrue(1 == PDNumberGetInteger(PDArrayGetElement(arr, 0)), @"array invalid");
    XCTAssertTrue(2 == PDNumberGetInteger(PDArrayGetElement(arr, 1)), @"array invalid");
    XCTAssertTrue(3 == PDNumberGetInteger(PDArrayGetElement(arr, 2)), @"array invalid");
    str = PDDictionaryGetEntry(PDObjectGetDictionary(object), "Far");// PDArrayGetElement(PDObjectGetArray(object), 2);
    XCTAssertNotNull(str, @"null string in dict");
    XCTAssertTrue(PDStringEqualsCString(str, "/Name"), @"string invalid");
    
    PDDictionarySetEntry(PDObjectGetDictionary(object), "Far", PDAutorelease(PDStringCreateWithName(strdup("/Other"))));
    XCTAssertTrue(2 == PDDictionaryGetCount(PDObjectGetDictionary(object)), @"object dict count invalid");
    PDObjectGenerateDefinition(object, &buf, 1024);
    XCTAssertTrue(0 == strcmp(buf, "1 0 obj\n<< /Zoo [ 1 2 3 ] /Far /Other >>\n"), @"object definition invalid");
    arr = PDDictionaryGetEntry(PDObjectGetDictionary(object), "Zoo");//PDArrayGetElement(PDObjectGetArray(object), 0);
    XCTAssertNotNull(arr, @"null array");
    XCTAssertTrue(3 == PDArrayGetCount(arr), @"array invalid");
    XCTAssertTrue(1 == PDNumberGetInteger(PDArrayGetElement(arr, 0)), @"array invalid");
    XCTAssertTrue(2 == PDNumberGetInteger(PDArrayGetElement(arr, 1)), @"array invalid");
    XCTAssertTrue(3 == PDNumberGetInteger(PDArrayGetElement(arr, 2)), @"array invalid");
    str = PDDictionaryGetEntry(PDObjectGetDictionary(object), "Far");// PDArrayGetElement(PDObjectGetArray(object), 2);
    XCTAssertNotNull(str, @"null string in dict");
    XCTAssertTrue(PDStringEqualsCString(str, "/Other"), @"string invalid");*/
    
    afterAll(^{
        PDRelease(object);
        free(buf);
    });
});

SpecEnd

//- (void)testObjectDicts
//{
//}
//
//- (void)configIn:(NSString *)file_in andOut:(NSString *)file_out
//{
//    if (_pipe) {
//        PDRelease(_pipe);
//    }
//    
//    XCTAssertNotNil(file_in, @"input file not found in bundle");
//    XCTAssertNotNil(file_out, @"output file path creation failure");
//    
//    _fm = [NSFileManager defaultManager];
//    XCTAssertTrue([_fm fileExistsAtPath:file_in], @"input file not found: %@", file_in);
//    [_fm createDirectoryAtPath:NSTemporaryDirectory() withIntermediateDirectories:YES attributes:nil error:nil];
//    [_fm removeItemAtPath:file_out error:NULL];
//    
//    _pipe = PDPipeCreateWithFilePaths([file_in cStringUsingEncoding:NSUTF8StringEncoding], [file_out cStringUsingEncoding:NSUTF8StringEncoding]);
//    
//    XCTAssertNotNull(_pipe, @"PDPipeRef creation failed");
//    if (! _pipe) {
//        BriefLog(@"PDPipeCreateWithFilePaths(\n\t%@\n\t%@\n)", file_in, file_out);
//        assert(0);
//    }
//}
//
//- (void)configStd
//{
//    NSString *file_in  = [[NSBundle bundleForClass:self.class] pathForResource:PIPE_FILE_IN_BASE ofType:@"pdf"];
//    NSString *file_out = [NSTemporaryDirectory() stringByAppendingPathComponent:PIPE_FILE_OUT];
//    
//    [self configIn:file_in andOut:file_out];
//}
//
//- (void)configStdVerify
//{
//    NSString *file_in = [NSTemporaryDirectory() stringByAppendingPathComponent:PIPE_FILE_OUT];
//    NSString *file_out  = @"/dev/null";
//    
//    [self configIn:file_in andOut:file_out];
//}
//
//#endif // TEST_PAJDEG*
//
//#ifdef TEST_PAJDEG
//
//- (BOOL)helperComparator:(NSString *)path expected:(id)expected got:(void *)input //destroy:(BOOL)destroy
//{
//    PDInstanceType type = PDResolve(input);
//    BOOL finalResult = YES;
//    BOOL subResult;
//    if ([expected isKindOfClass:[NSDictionary class]]) {
//        XCTAssertEqual(type, PDInstanceTypeDict, @"%@ wrong type", path);
//        if (type != PDInstanceTypeDict) return NO;
//        
//        NSArray *keys = [expected allKeys];
//        NSInteger count = [keys count];
//        void *v;
//        for (NSInteger i = 0; i < count; i++) {
//            NSString *key = keys[i];
//            id expect = expected[key];
//            v = PDDictionaryGetEntry(input, key.PDFString);
//            //            v = pd_dict_get_copy(input, [key cStringUsingEncoding:NSUTF8StringEncoding]);
//            subResult = [self helperComparator:[path stringByAppendingFormat:@" %@", key] expected:expect got:v];
//            XCTAssertTrue(subResult, @"%@ sub result failure for key %@", path, key);
//            finalResult &= subResult;
//        }
//        //        if (destroy) pd_dict_destroy(input);
//        return finalResult;
//    }
//    else if ([expected isKindOfClass:[NSArray class]]) {
//        XCTAssertEqual(type, PDInstanceTypeArray, @"%@ wrong type", path);
//        if (type != PDInstanceTypeArray) return NO;
//        
//        NSInteger count = [expected count];
//        void *v;
//        for (NSInteger i = 0; i < count; i++) {
//            id expect = expected[i];
//            v = PDArrayGetElement(input, i);
//            //            v = pd_array_get_copy_at_index(input, i);
//            subResult = [self helperComparator:[path stringByAppendingString:@" ["] expected:expect got:v];
//            XCTAssertTrue(subResult, @"%@ sub result failure for index %ld", path, (long)i);
//            finalResult &= subResult;
//        }
//        //        if (destroy) pd_array_destroy(input);
//        return finalResult;
//    }
//    else if ([expected isKindOfClass:[NSValue class]]) {
//        XCTAssertEqual(type, PDInstanceTypeRef, @"%@ wrong type", path);
//        if (type != PDInstanceTypeRef) return NO;
//        
//        PDReferenceRef ref = [(NSValue *)expected pointerValue];
//        PDReferenceRef got = (PDReferenceRef)input;
//        XCTAssertEqual(PDReferenceGetObjectID(ref), PDReferenceGetObjectID(got), @"%@: ref ob id failure", path);
//        XCTAssertEqual(PDReferenceGetGenerationID(ref), PDReferenceGetGenerationID(got), @"%@: ref gen number failure", path);
//        finalResult = PDReferenceGetObjectID(ref) == PDReferenceGetObjectID(got) && PDReferenceGetGenerationID(ref) == PDReferenceGetGenerationID(got);
//        PDRelease(ref);
//        //        if (destroy) PDRelease(got);
//        return finalResult;
//    }
//    else if ([expected isKindOfClass:[NSString class]]) {
//        XCTAssertEqual(type, PDInstanceTypeString, @"%@ wrong type", path);
//        if (type != PDInstanceTypeString) return NO;
//        
//        NSString *got = [NSString stringWithPDFString:[expected hasPrefix:@"<"] ? PDStringHexValue(input, true) : PDStringEscapedValue(input, false)];//stringWithCString:(char *)input encoding:NSUTF8StringEncoding];
//        XCTAssertEqualObjects(got, expected, @"%@", path);
//        assert([got isEqualToString:expected] == [got isEqual:expected]);
//        //        if (destroy) free(input);
//        return [got isEqualToString:expected];
//    }
//    
//    XCTFail(@"unexpected type %@ in %@", NSStringFromClass(expected), expected);
//    return NO;
//}
//
//- (void)testObjectCopies
//{
//    NSDictionary *defdict = @{@"String": @"a string",
//                              @"Hexstring": @"<abc123>",
//                              @"Ref": [NSValue valueWithPointer:PDReferenceCreate(10, 0)],
//                              @"Arr": (@[
//                                         @"arrstring",
//                                         @"<abc456>",
//                                         [NSValue valueWithPointer:PDReferenceCreate(11, 0)],
//                                         (@{
//                                            @"Thisis": @"a dict in an array",
//                                            @"Diaref": [NSValue valueWithPointer:PDReferenceCreate(14, 0)]
//                                            })
//                                         ]),
//                              @"Dict": (@{
//                                          @"Dictstr": @"dict string",
//                                          @"Dicthexstr": @"<abc789>",
//                                          @"Dictref": [NSValue valueWithPointer:PDReferenceCreate(12, 0)],
//                                          @"Dictarr": (@[
//                                                         @"arr2str",
//                                                         @"<abcabc>",
//                                                         [NSValue valueWithPointer:PDReferenceCreate(13, 0)]
//                                                         ])
//                                          })
//                              };
//    char *defstr = "<< /String (a string) /Hexstring <abc123> /Ref 10 0 R /Arr [ (arrstring) <abc456> 11 0 R << /Thisis (a dict in an array) /Diaref 14 0 R >> ] /Dict << /Dictstr (dict string) /Dicthexstr <abc789> /Dictref 12 0 R /Dictarr [ (arr2str) <abcabc> 13 0 R ] >> >>";
//    
//    pd_stack def = PDScannerGenerateStackFromFixedBuffer(arbStream, defstr, strlen(defstr));
//    XCTAssertNotNull(def, @"Failed to generate stack from definitions string!");
//    PDObjectRef ob = PDObjectCreateFromDefinitionsStack(1, def);
//    
//    BOOL result = [self helperComparator:@"" expected:defdict got:PDObjectGetDictionary(ob)];
//    XCTAssertTrue(result, @"Object copy code failure");
//    PDRelease(ob);
//}
//
//- (void)testRetainedTypes
//{
//    PDObjectRef ob = PDObjectCreate(0, 0);
//    char *uabuf = "hello";
//    PDObjectSetStream(ob, uabuf, 5, true, false, false);
//    XCTAssertEqual(uabuf, ob->ovrStream, @"Unallocated buffer is not pointed to by object stream.");
//    PDRelease(ob); // <-- crash = uabuf was freed invalidly
//    
//    ob = PDObjectCreate(0, 0);
//    char *abuf = strdup("hello");
//    PDObjectSetStream(ob, abuf, 5, true, true, false);
//    PDRelease(ob); // <-- leak = abuf was not freed as it should have been (not sure how to check if leaking or not, tbh)
//}
//
//- (void)testScannerNestedParentheses
//{
//#define EXP1 "(Parenthesis)"
//#define EXP2 "(Paren\\(thes\\)is)"
//#define EXP3 "(Pa\\(ren\\)th\\(e\\(s\\)\\)is)"
//#define EXP4 "(Par ens \\(in the\\) hood)"
//#define INP1 "(Parenthesis)"
//#define INP2 "(Paren(thes)is)"
//#define INP3 "(Pa(ren)th(e(s))is)"
//#define INP4 "(Par ens (in the) hood)"
//    
//    pd_pdf_implementation_use();
//    char *req[] = {EXP1, EXP2, EXP3, EXP4};
//    char *buf = ("<< /Par " INP1 " >>\n"
//                 "<< /Par2 " INP2 " >>\n"
//                 "<< /Par3 " INP3 " >>\n"
//                 "<< /Par4 " INP4 " >>\n");
//    
//    PDScannerRef scn = PDScannerCreateWithState(pdfRoot);
//    scn->buf = buf;
//    scn->fixedBuf = true;
//    scn->bsize = strlen(buf);
//    scn->boffset = 0;
//    pd_stack stack;
//    
//    int ix = 4;
//    for (int i = 0; i < ix; i++) {
//        XCTAssertTrue(true == PDScannerPopStack(scn, &stack), @"Scanner did not pop a stack as expected.");
//        PDDictionaryRef d = PDInstanceCreateFromComplex(&stack);
//        PDDictionaryPrint(d);
//        PDStringRef s = PDDictionaryGetEntry(d, [i > 0 ? [NSString stringWithFormat:@"Par%d", i+1] : @"Par" PDFString]);
//        XCTAssertTrue(0 == strcmp(req[i], PDStringEscapedValue(s, true)), @"invalid result: %s", PDStringEscapedValue(s, true));
//        //        XCTAssertTrue(0 == strcmp(req[i], (((pd_stack)((pd_stack)stack->prev->prev->info)->info)->prev->prev->info)), @"invalid result: %s", (((pd_stack)((pd_stack)stack->prev->prev->info)->info)->prev->prev->info));
//        PDRelease(d);
//        pd_stack_destroy(&stack);
//    }
//    
//    PDRelease(scn);
//    
//    pd_pdf_implementation_discard();
//}
//
//- (void)testOpen
//{
//    [self configStd];
//    
//    long long objects = PDPipeExecute(_pipe);
//    XCTAssertTrue(objects > -1, @"PDPipeExecute() returned error code");
//    NSLog(@"objects: %lld", objects);
//}
//
//- (NSString *)bufDesc:(char *)buf len:(PDInteger)len
//{
//    char *res = malloc(1 + len * 4);
//    int j =0;
//    for (int i = 0; i < len; i++)
//        if (buf[i] < 32 || buf[i] > 'z') {
//            j += sprintf(&res[j], "\\%03d", buf[i]);
//        } else {
//            res[j++] = buf[i];
//        }
//    res[j] = 0;
//    NSString *str = [NSString stringWithFormat:@"[ %s ] (%ldb)", res, len];
//    free(res);
//    return str;
//}
//
//- (void)runSingleFilterTest:(NSString *)name filter:(PDStreamFilterRef)filter
//{
//#define BUF_CAP_INIT 16
//#define BUF_CAP_GROW 8
//    int buf_cap = BUF_CAP_INIT;
//    PDInteger len_ns;
//    char *seg;
//    
//    XCTAssertFalse(!PDStreamFilterInit(filter), @"%@ filter init failed", name);
//    PDStreamFilterPrepare(filter, buf_in, len_in, buf_out, buf_cap);
//    
//    len_out = PDStreamFilterBegin(filter);
//    while (! filter->finished && ! filter->failing) {
//        buf_cap += BUF_CAP_GROW;
//        buf_out = realloc(buf_out, buf_cap);
//        filter->bufOut = (unsigned char *)(buf_out + len_out);
//        filter->bufOutCapacity += BUF_CAP_GROW;
//        len_out += PDStreamFilterProceed(filter);
//    }
//    XCTAssertFalse(filter->failing, @"%@ Filter is failing!", name);
//    
//    XCTAssertTrue(len_out > 0, @"%@ filter returned 0 bytes on process call.", name);
//    
//    // reinit filter
//    XCTAssertTrue(true == PDStreamFilterDone(filter), @"Deinitialization of filter failed");
//    XCTAssertTrue(true == PDStreamFilterInit(filter), @"(Re)initialization of deinitialized filter failed");
//    
//    seg = buf_out;
//    len_ns = len_out + len_out/2;
//    if (len_ns < 128) len_ns = 128;
//    buf_out = malloc(len_ns);
//    PDStreamFilterPrepare(filter, buf_in, len_in, buf_out, len_ns);
//    len_ns = PDStreamFilterBegin(filter);
//    XCTAssertTrue(true == filter->finished, @"Filter did not finish despite being given enough buffer space (1.5*expected output, minimum 128b).");
//    XCTAssertTrue(false == filter->failing, @"Filter is failing");
//    XCTAssertEqual(len_ns, len_out, @"Segmented length and non-segmented length do not match up");
//    XCTAssertTrue(0 == memcmp(seg, buf_out, len_out), @"Memory comparison of segmented vs non-segmented filter results do not match.");
//    free(seg);
//    
//    PDRelease(filter);
//}
//
//- (void)runFilterTest:(NSString *)name filterIn:(PDStreamFilterRef)filterIn filterOut:(PDStreamFilterRef)filterOut string:(char *)string
//{
//    // this is zlib compression/decompression without prediction 
//    char *expect_in;
//    PDInteger len_x;
//    
//    len_x = len_in = strlen(string);
//    expect_in = malloc(len_in);
//    buf_in = malloc(len_in);
//    buf_out = malloc(BUF_CAP_INIT);
//    
//    strcpy(expect_in, string); //"Hello, World!@#$%^&*().");  // we expect this on the way back
//    strcpy(buf_in, expect_in);
//    
//    XCTAssertTrue(0 == strcmp(expect_in, buf_in), @"Setup of input / expect buffers is broken.");
//    
//    NSLog(@"%@: start = %@", name, [self bufDesc:buf_in len:len_in]);
//    
//    [self runSingleFilterTest:[NSString stringWithFormat:@"%@ IN", name] filter:filterIn];
//    
//    NSLog(@"%@: out = %@", name, [self bufDesc:buf_out len:len_out]);
//    
//    // we don't keep some right answer lying around, although in reality we probably should; for now just check that it decompresses right
//    
//    free(buf_in);
//    len_in = len_out;
//    buf_in = buf_out;
//    buf_out = malloc(BUF_CAP_INIT);
//    
//    [self runSingleFilterTest:[NSString stringWithFormat:@"%@ OUT", name] filter:filterOut];
//    
//    XCTAssertEqual((int)len_out,(int) len_x, @"%@ OUT filter did not come back with same length as it was given", name);
//    
//    NSLog(@"%@: back = %@", name, [self bufDesc:buf_out len:len_out]);
//    
//    XCTAssertTrue(0 == strncmp(expect_in, buf_out, len_out), @"%@ did not return an identical string as it was given", name);
//    
//    free(expect_in);
//    free(buf_in);
//    free(buf_out);
//}
//
//- (void)runFilterTest:(NSString *)name filterIn:(PDStreamFilterRef)filterIn filterOut:(PDStreamFilterRef)filterOut
//{
//    [self runFilterTest:name filterIn:filterIn filterOut:filterOut string:"Hello, World!@#$%^&*().."];
//}
//
//- (void)testFlateDecode
//{
//    [self configStd];
//    
//    PDStreamFilterRef zipFilter = PDStreamFilterObtain("FlateDecode", false, NULL);
//    XCTAssertFalse(NULL == zipFilter, @"FlateDecode (ZIP) filter not found (reader).");
//    
//    PDStreamFilterRef unzipFilter = PDStreamFilterObtain("FlateDecode", true, NULL);
//    XCTAssertFalse(NULL == unzipFilter, @"FlateDecode (UNZIP) filter not found (writer).");
//    
//    [self runFilterTest:@"ZIP" filterIn:zipFilter filterOut:unzipFilter];
//}
//
//- (void)testFlateDecodeInverter
//{
//    [self configStd];
//    
//    PDStreamFilterRef zipFilter = PDStreamFilterObtain("FlateDecode", false, NULL);
//    XCTAssertFalse(NULL == zipFilter, @"FlateDecode (ZIP) filter not found (reader).");
//    
//    PDStreamFilterRef unzipFilter = PDStreamFilterCreateInversionForFilter(zipFilter);
//    XCTAssertFalse(NULL == unzipFilter, @"Inversion for ZIP is null");
//    
//    [self runFilterTest:@"ZIP(inv)" filterIn:zipFilter filterOut:unzipFilter];
//}
//
//- (void)testPredictor
//{
//    [self configStd];
//    
//    PDDictionaryRef options = [@{@"Columns": @(6), @"Predictor": @(12)} PDValue]; //pd_stack_create_from_definition
//    //    (PDDef("6", "Columns",
//    //         "12", "Predictor"));
//    
//    PDStreamFilterRef pred = PDStreamFilterObtain("Predictor", false, options);
//    XCTAssertFalse(NULL == pred, @"Predictor filter not found.");
//    
//    options = [@{@"Columns": @(6), @"Predictor": @(12)} PDValue];
//    //    pd_stack_create_from_definition
//    //    (PDDef("6", "Columns",
//    //           "12", "Predictor"));
//    
//    PDStreamFilterRef unpred = PDStreamFilterObtain("Predictor", true, options);
//    XCTAssertFalse(NULL == unpred, @"Unpredictor filter not found.");
//    
//    [self runFilterTest:@"Predictor" filterIn:pred filterOut:unpred];
//}
//
//- (void)testPredictorInverter
//{
//    [self configStd];
//    
//    PDDictionaryRef options = [@{@"Columns": @(6), @"Predictor": @(12)} PDValue];
//    //    pd_stack_create_from_definition
//    //    (PDDef("6", "Columns",
//    //           "12", "Predictor"));
//    
//    PDStreamFilterRef pred = PDStreamFilterObtain("Predictor", false, options);
//    XCTAssertFalse(NULL == pred, @"Predictor filter not found.");
//    
//    PDStreamFilterRef unpred = PDStreamFilterCreateInversionForFilter(pred);
//    XCTAssertFalse(NULL == unpred, @"Unpredictor filter not found.");
//    
//    [self runFilterTest:@"Predictor(inv)" filterIn:pred filterOut:unpred];
//}
//
//- (void)testFlateDecodePredictor
//{
//    [self configStd];
//    
//    // predict + compress
//    
//    PDDictionaryRef options = [@{@"Columns": @(6), @"Predictor": @(12)} PDValue];
//    //    pd_stack options = pd_stack_create_from_definition
//    //    (PDDef("6", "Columns",
//    //           "12", "Predictor"));
//    
//    PDStreamFilterRef pred = PDStreamFilterObtain("Predictor", false, options);
//    XCTAssertFalse(NULL == pred, @"Predictor filter not found.");
//    
//    options = [@{@"Columns": @(6), @"Predictor": @(12)} PDValue];
//    //    options = pd_stack_create_from_definition
//    //    (PDDef("6", "Columns",
//    //           "12", "Predictor"));
//    
//    PDStreamFilterRef unpred = PDStreamFilterObtain("Predictor", true, options);
//    XCTAssertFalse(NULL == unpred, @"Unpredictor filter not found.");
//    
//    
//    
//    PDStreamFilterRef flate = PDStreamFilterObtain("FlateDecode", false, NULL);
//    XCTAssertFalse(NULL == flate, @"Flate filter not found.");
//    
//    PDStreamFilterRef deflate = PDStreamFilterObtain("FlateDecode", true, NULL);
//    XCTAssertFalse(NULL == deflate, @"Deflate filter not found.");
//    
//    XCTAssertTrue(NULL == pred->nextFilter, @"Predictor had a non-NULL nextFilter on creation");
//    XCTAssertTrue(NULL == unpred->nextFilter, @"Unpredictor had a non-NULL nextFilter on creation");
//    XCTAssertTrue(NULL == flate->nextFilter, @"Flate filter had a non-NULL nextFilter on creation");
//    XCTAssertTrue(NULL == deflate->nextFilter, @"Deflate filter had a non-NULL nextFilter on creation");
//    
//    pred->nextFilter = flate;
//    deflate->nextFilter = unpred;
//    
//    [self runFilterTest:@"FlateDecode+Predictor" filterIn:pred filterOut:deflate];
//#if 0    
//    char *expect_in, *buf_in, *buf_out;
//    int len_in, len_out;
//    
//    expect_in = malloc(128);
//    buf_in = malloc(128);
//    buf_out = malloc(128);
//    
//    strcpy(expect_in, 
//           "Hello,"
//           " World"
//           "!@#$%^"
//           "&*()..");  // we expect this on the way back
//    strcpy(buf_in, expect_in);
//    
//    XCTAssertTrue(0 == strcmp(expect_in, buf_in), @"Setup of input / expect buffers is broken.");
//    len_in = strlen(buf_in);
//    
//    XCTAssertFalse(!PDStreamFilterInit(pred), @"Prediction filter init failed");
//    PDStreamFilterPrepare(pred, buf_in, len_in, buf_out, 128);
//    
//    NSLog(@"Pred: start = %@", [self bufDesc:buf_in len:len_in]);
//    
//    len_out = PDStreamFilterBegin(pred);
//    
//    XCTAssertTrue(len_out > 0, @"Pred filter returned 0 bytes on process call.");
//    PDRelease(pred);
//    
//    NSLog(@"Pred: out = %@", [self bufDesc:buf_out len:len_out]);
//    
//    // we don't keep some right answer lying around, although in reality we probably should; for now just check that it decompresses right
//    
//    XCTAssertFalse(!PDStreamFilterInit(deflate), @"Unprediction filter init failed");
//    PDStreamFilterPrepare(deflate, buf_out, len_out, buf_in, len_in);
//    
//    XCTAssertEquals((int)len_in, (int)PDStreamFilterBegin(deflate), @"Deflate filter did not come back with same length as it was given");
//    
//    NSLog(@"Pred: back = %@", [self bufDesc:buf_in len:len_in]);
//    
//    XCTAssertTrue(0 == strcmp(expect_in, buf_in), @"Deflate did not return an identical string as it was given");
//    PDRelease(deflate);
//    
//    free(expect_in);
//    free(buf_in);
//    free(buf_out);
//#endif
//}
//
//- (void)testFlateDecodePredictorInversion
//{
//    [self configStd];
//    
//    // predict + compress
//    
//    PDDictionaryRef options = [@{@"Columns": @(6), @"Predictor": @(12)} PDValue];
//    //    pd_stack options = pd_stack_create_from_definition
//    //    (PDDef("6", "Columns",
//    //           "12", "Predictor"));
//    
//    PDStreamFilterRef pred = PDStreamFilterObtain("Predictor", false, options);
//    XCTAssertFalse(NULL == pred, @"Predictor filter not found.");
//    
//    PDStreamFilterRef flate = PDStreamFilterObtain("FlateDecode", false, NULL);
//    XCTAssertFalse(NULL == flate, @"Flate filter not found.");
//    
//    
//    
//    XCTAssertTrue(NULL == pred->nextFilter, @"Predictor had a non-NULL nextFilter on creation");
//    XCTAssertTrue(NULL == flate->nextFilter, @"Flate filter had a non-NULL nextFilter on creation");
//    
//    pred->nextFilter = flate;
//    
//    PDStreamFilterRef deflate = PDStreamFilterCreateInversionForFilter(pred);
//    
//    [self runFilterTest:@"FlateDecode+Predictor(inv)" filterIn:pred filterOut:deflate];
//}
//
//- (void)testFlateDecodePredictorInversionMultipass
//{
//    [self configStd];
//    
//    // predict + compress
//    
//    PDDictionaryRef options = [@{@"Columns": @(6), @"Predictor": @(12)} PDValue];
//    //    pd_stack options = pd_stack_create_from_definition
//    //    (PDDef("6", "Columns",
//    //           "12", "Predictor"));
//    
//    PDStreamFilterRef pred = PDStreamFilterObtain("Predictor", false, options);
//    XCTAssertFalse(NULL == pred, @"Predictor filter not found.");
//    
//    PDStreamFilterRef flate = PDStreamFilterObtain("FlateDecode", false, NULL);
//    XCTAssertFalse(NULL == flate, @"Flate filter not found.");
//    
//    
//    
//    XCTAssertTrue(NULL == pred->nextFilter, @"Predictor had a non-NULL nextFilter on creation");
//    XCTAssertTrue(NULL == flate->nextFilter, @"Flate filter had a non-NULL nextFilter on creation");
//    
//    pred->nextFilter = flate;
//    
//    PDStreamFilterRef deflate = PDStreamFilterCreateInversionForFilter(pred);
//    
//    [self runFilterTest:@"FlateDecode+Predictor(inv)" filterIn:pred filterOut:deflate string:"012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345012345"];
//}
//
//PDTaskResult taskTestFunc(PDPipeRef pipe, PDTaskRef task, PDObjectRef object, void *info)
//{
//    return PDTaskDone;
//}
//
//- (void)testFilter
//{
//    [self configStd];
//    
//    PDTaskRef filter, task;
//    filter = PDTaskCreateFilter(PDPropertyRootObject);
//    task = PDTaskCreateMutator(taskTestFunc);
//    PDTaskAppendTask(filter, task);
//    PDPipeAddTask(_pipe, filter);
//    
//    PDRelease(filter);
//    PDRelease(task);
//    
//    XCTAssertTrue(-1 < PDPipeExecute(_pipe), @"PDPipeExecute() returned error code");
//}
//
//- (void)testBlockTask
//{
//    [self configStd];
//    
//    PDTaskRef task;
//    task = PDITaskCreateBlockMutator(^PDTaskResult(PDPipeRef pipe, PDTaskRef task, PDObjectRef object) {
//        return PDTaskDone;
//    });
//    
//    PDPipeAddTask(_pipe, task);
//    
//    PDRelease(task);
//    
//    XCTAssertTrue(-1 < PDPipeExecute(_pipe), @"PDPipeExecute() returned error code");
//}
//
//- (void)testSinglePageCopying
//{
//    [self configStd];
//    
//    PDPipeRef pipe2 = _pipe;
//    _pipe = NULL;
//    NSString *file_in  = [[NSBundle bundleForClass:self.class] pathForResource:@"Skycatch_v3.infinite" ofType:@"pdf"];
//    
//    [self configIn:file_in andOut:@"/dev/null"];
//    
//    PDPageRef page = PDPageCreateForPageWithNumber(PDPipeGetParser(_pipe), 2);
//    XCTAssertNotNull(page, @"page creation failure");
//    PDPageRef impPage = PDPageInsertIntoPipe(page, pipe2, 3);
//    XCTAssertNotNull(impPage, @"page import failure");
//    PDRelease(page);
//    
//    PDPipeExecute(pipe2);
//    PDPipeExecute(_pipe);
//    
//    PDRelease(pipe2);
//}
//
//- (void)testSinglePageAppending
//{
//    [self configStd];
//    
//    PDPipeRef pipe2 = _pipe;
//    _pipe = NULL;
//    NSString *file_in  = [[NSBundle bundleForClass:self.class] pathForResource:@"Skycatch_v3.infinite" ofType:@"pdf"];
//    
//    [self configIn:file_in andOut:@"/dev/null"];
//    
//    NSInteger count = PDCatalogGetPageCount(PDParserGetCatalog(PDPipeGetParser(pipe2)));
//    
//    PDPageRef page = PDPageCreateForPageWithNumber(PDPipeGetParser(_pipe), 2);
//    XCTAssertNotNull(page, @"page creation failure");
//    PDPageRef impPage = PDPageInsertIntoPipe(page, pipe2, 4);
//    XCTAssertNotNull(impPage, @"page import failure");
//    
//    PDRelease(page);
//    PDPipeExecute(pipe2);
//    PDPipeExecute(_pipe);
//    
//    PDRelease(pipe2);
//    
//    [self configStdVerify];
//    
//    NSInteger count2 = PDCatalogGetPageCount(PDParserGetCatalog(PDPipeGetParser(_pipe)));
//    
//    XCTAssert(count2 == count + 1, @"Count was not updated correctly.");
//    
//}
//
//- (void)testMultiPageCopying
//{
//    [self configStd];
//    
//    PDPipeRef pipe2 = _pipe;
//    _pipe = NULL;
//    NSString *file_in  = [[NSBundle bundleForClass:self.class] pathForResource:@"Skycatch_v3.infinite" ofType:@"pdf"];
//    
//    [self configIn:file_in andOut:@"/dev/null"];
//    
//    PDPageRef page = PDPageCreateForPageWithNumber(PDPipeGetParser(_pipe), 2);
//    XCTAssertNotNull(page, @"page creation failure");
//    PDPageRef impPage = PDPageInsertIntoPipe(page, pipe2, 3);
//    XCTAssertNotNull(impPage, @"page import failure");
//    
//    PDPageRef page2 = PDPageCreateForPageWithNumber(PDPipeGetParser(_pipe), 3);
//    XCTAssertNotNull(page2, @"page creation failure");
//    PDPageRef impPage2 = PDPageInsertIntoPipe(page2, pipe2, 4);
//    XCTAssertNotNull(impPage2, @"page import failure");
//    
//    PDRelease(page);
//    PDRelease(page2);
//    
//    PDPipeExecute(pipe2);
//    PDPipeExecute(_pipe);
//    
//    PDRelease(pipe2);
//}
//
//- (void)testMultiPageAppending
//{
//    [self configStd];
//    
//    PDPipeRef pipe2 = _pipe;
//    _pipe = NULL;
//    NSString *file_in  = [[NSBundle bundleForClass:self.class] pathForResource:@"Skycatch_v3.infinite" ofType:@"pdf"];
//    
//    [self configIn:file_in andOut:@"/dev/null"];
//    
//    PDPageRef page = PDPageCreateForPageWithNumber(PDPipeGetParser(_pipe), 2);
//    XCTAssertNotNull(page, @"page creation failure");
//    PDPageRef impPage = PDPageInsertIntoPipe(page, pipe2, 3);
//    XCTAssertNotNull(impPage, @"page import failure");
//    
//    PDPageRef page2 = PDPageCreateForPageWithNumber(PDPipeGetParser(_pipe), 3);
//    XCTAssertNotNull(page2, @"page creation failure");
//    PDPageRef impPage2 = PDPageInsertIntoPipe(page2, pipe2, 5);
//    XCTAssertNotNull(impPage2, @"page import failure");
//    
//    PDRelease(page);
//    PDRelease(page2);
//    
//    PDPipeExecute(pipe2);
//    PDPipeExecute(_pipe);
//    
//    PDRelease(pipe2);
//}
//
//- (void)runSet:(NSArray *)set inPath:(NSString *)path moveInfsTo:(NSString *)infPath code:(void (^)(NSString *pdf, NSString *path, NSString *out1, NSString *out2))code
//{
//    NSFileManager *fm = [NSFileManager defaultManager];
//    
//    if (code == NULL) code = ^(NSString *pdf, NSString *path, NSString *out1, NSString *out2) {
//        XCTAssertTrue([fm fileExistsAtPath:[path stringByAppendingString:pdf]], @"PDF not found in filesystem!");
//        [self configIn:[path stringByAppendingString:pdf] andOut:out1];
//        PDPipeExecute(_pipe);
//        //        PDRelease(_pipe);
//        XCTAssertTrue([fm fileExistsAtPath:out1], @"Pajdeg original failure %@", pdf);
//        NSLog(@"*** PAJDEG RECIPE TEST %@ *** ", pdf);
//        [self configIn:out1 andOut:out2];
//        PDPipeExecute(_pipe);
//        PDRelease(_pipe);
//        _pipe = nil;
//        XCTAssertTrue([fm fileExistsAtPath:out2], @"Pajdeg internal failure %@", pdf);
//    };
//    
//    NSString *out1 = [NSTemporaryDirectory() stringByAppendingString:@"/out1.pdf"];
//    NSString *out2 = [NSTemporaryDirectory() stringByAppendingString:@"/out2.pdf"];
//    for (NSString *pdf in set) {
//        //if (! [pdf hasPrefix:@"Tactics of Persuasion"]) continue;
//        if ([[[pdf pathExtension] lowercaseString] isEqualToString:@"pdf"]) {
//            NSLog(@"*** PAJDEG ORIG TEST %@ *** ", pdf);
//            if ([[pdf lowercaseString] hasSuffix:@".infinite.pdf"]) {
//                // *SLAP*
//                [fm removeItemAtPath:[infPath stringByAppendingString:pdf] error:NULL];
//                [fm moveItemAtPath:[path stringByAppendingString:pdf] toPath:[infPath stringByAppendingString:pdf] error:NULL];
//            } else {
//                code(pdf, path, out1, out2);
//            }
//        }
//    }
//}
//
//- (void)testCatalogCreation
//{
//    // catalog generation would break Fate Accel
//    NSString *path = PAJDEG_PDFS;
//    // this only works in simulator so we check if file exists
//    if ([[NSFileManager defaultManager] fileExistsAtPath:[path stringByAppendingString:@"Fate Accelerated Electronic Edition.pdf"]]) {
//        [self configIn:[path stringByAppendingString:@"Fate Accelerated Electronic Edition.pdf"] andOut:@"/dev/null"];
//        if (! _pipe) {
//            XCTFail(@"pipe creation failure");
//            return;
//        }
//        PDParserGetCatalog(PDPipeGetParser(_pipe));
//        PDPipeExecute(_pipe);
//        PDRelease(_pipe);
//        _pipe = nil;
//    }
//}
//
//- (void)testTestPDFSet
//{
//    NSArray *set = @[@"Capture.pdf", @"Chinese_traditional.pdf", @"Japanese.pdf", @"PDF13.pdf", @"PDF15.pdf", @"Tagged.pdf", @"Untagged.pdf", @"Chinese_simplified.pdf", @"Forms.pdf", @"Korean.pdf", @"PDF14.pdf", @"PDF16.pdf", @"TouchUp.pdf"];
//    NSString *path = [[NSBundle bundleForClass:self.class] pathForResource:@"Capture" ofType:@"pdf"];
//    path = [path substringToIndex:path.length - strlen("Capture.pdf")];
//    [self runSet:set inPath:path moveInfsTo:NSTemporaryDirectory() code:NULL];
//}
//
//- (void (^)(NSString *pdf, NSString *path, NSString *out1, NSString *out2))catalogBlock
//{
//    NSFileManager *fm = [NSFileManager defaultManager];
//    return [^(NSString *pdf, NSString *path, NSString *out1, NSString *out2) {
//        [self configIn:[path stringByAppendingString:pdf] andOut:out1];
//        if (NULL == PDPipeGetParser(_pipe)) {
//            XCTFail(@"NULL pipe in PDF test for %@", pdf);
//            return;
//        }
//        
//        PDCatalogRef catalog = PDParserGetCatalog(PDPipeGetParser(_pipe));
//        NSInteger pageCount = PDCatalogGetPageCount(catalog);
//        __block NSInteger pagesSeen = 0;
//        __block NSInteger pagesSeen2 = 0;
//        __block NSInteger pagesInObStreams = 0;
//        __block NSInteger *pageIDs = malloc(sizeof(NSInteger) * pageCount);
//        
//        __block NSInteger *pageIDs2 = malloc(sizeof(NSInteger) * pageCount);
//        PDTaskRef pageBlock2 = PDITaskCreateBlockMutator(^PDTaskResult(PDPipeRef pipe, PDTaskRef task, PDObjectRef object) {
//            PDInteger obid = PDObjectGetObID(object);
//            pagesInObStreams += PDObjectGetObStreamFlag(object) == true;
//            BOOL found = NO;
//            for (NSInteger i = 0; i < pageCount; i++) {
//                if (pageIDs2[i] == obid) {
//                    pageIDs2[i] = -pageIDs[i];
//                    found = YES;
//                    break;
//                }
//                if (pageIDs2[i] == -obid) {
//                    // duplicate!
//                    XCTFail(@"duplicate entry for page %ld (id %ld)!", (long)i, (long)obid);
//                    found = YES;
//                    break;
//                }
//            }
//            XCTAssertTrue(found, @"Page with object ID=%ld was not found", (long)obid);
//            pagesSeen2++;
//            return PDTaskDone;
//        });
//        
//        PDTaskRef pageFilter;
//        for (NSInteger i = 0; i < pageCount; i++) {
//            pageIDs[i] = pageIDs2[i] = PDCatalogGetObjectIDForPage(catalog, i+1);
//            pageFilter = PDTaskCreateFilterWithValue(PDPropertyPage, i+1);
//            PDTaskAppendTask(pageFilter, pageBlock2);
//            PDPipeAddTask(_pipe, pageFilter);
//            PDRelease(pageFilter);
//        }
//        pageFilter = PDTaskCreateFilterWithValue(PDPropertyPDFType, PDFTypePage);
//        PDTaskRef pageBlock = PDITaskCreateBlockMutator(^PDTaskResult(PDPipeRef pipe, PDTaskRef task, PDObjectRef object) {
//            PDInteger obid = PDObjectGetObID(object);
//            BOOL found = NO;
//            for (NSInteger i = 0; i < pageCount; i++) {
//                if (pageIDs[i] == obid) {
//                    pageIDs[i] = -pageIDs[i];
//                    found = YES;
//                    break;
//                }
//                if (pageIDs[i] == -obid) {
//                    // duplicate!
//                    XCTFail(@"duplicate page %@::%ld (i=%ld)!", pdf, (long)obid, (long)i);
//                    found = YES;
//                    break;
//                }
//            }
//            //            XCTAssertTrue(found, @"Page %@::<#%ld> not found", pdf, (long)obid);
//            pagesSeen += found;
//            return PDTaskDone;
//        });
//        PDTaskAppendTask(pageFilter, pageBlock);
//        PDPipeAddTask(_pipe, pageFilter);
//        PDRelease(pageBlock);
//        PDRelease(pageFilter);
//        
//        PDPipeExecute(_pipe);
//        PDRelease(_pipe);
//        _pipe = nil;
//        XCTAssertTrue([fm fileExistsAtPath:out1], @"Pajdeg original failure %@", pdf);
//        
//        XCTAssertEqual(pageCount, pagesSeen + pagesInObStreams, @"%@: Not all pages were passed to the PDF TYPE block.", pdf);
//        XCTAssertEqual(pageCount, pagesSeen2, @"%@: Not all pages were passed to the PAGES block.", pdf);
//        
//        /*NSLog(@"*** PAJDEG RECIPE TEST %@ *** ", pdf);
//         [self configIn:out1 andOut:out2];
//         PDPipeExecute(_pipe);
//         PDRelease(_pipe);
//         XCTAssertTrue([fm fileExistsAtPath:out2], @"Pajdeg internal failure %@", pdf);*/
//        free(pageIDs);
//        free(pageIDs2);
//    } copy];
//}
//
////#ifdef TEST_PAJDEG_FULL
//
//- (void)testFull
//{
//    NSLog(@"*** ABOUT TO PERFORM FULL PAJDEG TESTS -- THIS IS MEMORY AND TIME INTENSIVE ***");
//    NSFileManager *fm = [NSFileManager defaultManager];
//    
//    NSString *path = PAJDEG_PDFS;
//    NSString *infPath = [NSString stringWithFormat:@"/Users/%@/Workspace/pajdeg-inf-pdfs/", NSUserName()];
//    NSArray *pdfs = [fm contentsOfDirectoryAtPath:path error:NULL];
//    [self runSet:pdfs inPath:path moveInfsTo:infPath code:NULL];
//}
//
//- (void)testCatalogFull
//{
//    NSLog(@"*** ABOUT TO PERFORM FULL PAJDEG TESTS (CATALOG) -- THIS IS MEMORY AND TIME INTENSIVE ***");
//    NSFileManager *fm = [NSFileManager defaultManager];
//    
//    NSString *path = PAJDEG_PDFS;
//    NSString *infPath = [NSString stringWithFormat:@"/Users/%@/Workspace/pajdeg-inf-pdfs/", NSUserName()];
//    NSArray *pdfs = [fm contentsOfDirectoryAtPath:path error:NULL];
//    [self runSet:pdfs inPath:path moveInfsTo:infPath code:[self catalogBlock]];
//}
//
////#endif // TEST_PAJDEG_FULL
//
//#endif // TEST_PAJDEG
//
//@end
