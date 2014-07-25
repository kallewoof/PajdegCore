//
//  PDTypeTests.m
//  pajdeg
//
//  Created by Karl-Johan Alm on 25/07/14.
//  Copyright (c) 2014 Kalle Alm. All rights reserved.
//

#import "Pajdeg.h"
#import "PDDictionary.h"
#import "PDArray.h"
#import "PDString.h"
#import "PDReference.h"
#import "PDObject.h"
#import "PDNumber.h"
#import "PDScanner.h"
#import "pd_pdf_implementation.h"
#import "pd_internal.h"
#import "pd_stack.h"

SpecBegin(PDTypeTests)

pd_pdf_implementation_use();

describe(@"replacing objects", ^{
    char *test =
    "<< /Key /Value /Key2 3 0 R >>";
    
    PDScannerRef scn = PDScannerCreateWithState(pdfRoot);
    PDScannerAttachFixedSizeBuffer(scn, test, strlen(test));
    
    pd_stack stk;
    PDScannerPopStack(scn, &stk);
    PDObjectRef ob = PDObjectCreateFromDefinitionsStack(1, stk);
    PDDictionaryRef dict = PDObjectGetDictionary(ob);
    
    __block PDInteger bufcap = 128;
    __block char *buf = malloc(bufcap);
    __block PDInteger len = PDObjectGenerateDefinition(ob, &buf, bufcap);
    buf[len] = 0;
    
    afterAll(^{
        PDRelease(scn);
        PDRelease(ob);
        free(buf);
    });
    
    it(@"should give a valid definition", ^{
        expect(strcmp(buf, "1 0 obj\n<< /Key /Value /Key2 3 0 R >>\n")).to.equal(0);
    });

    it(@"should update object ref correctly", ^{
        // set /Key2 to self -- should swap 3 0 R to 1 0 R
        PDDictionarySetEntry(dict, "Key2", ob);
        
        len = PDObjectGenerateDefinition(ob, &buf, bufcap);
        buf[len] = 0;

        expect(strcmp(buf, "1 0 obj\n<< /Key /Value /Key2 1 0 R >>\n")).to.equal(0);
    });
    
    it(@"should add object ref correctly", ^{
        // set new /Key3 to 5 0 R
        PDReferenceRef ref = PDReferenceCreate(5, 0);
        PDDictionarySetEntry(dict, "Key3", ref);
        PDRelease(ref);
        
        len = PDObjectGenerateDefinition(ob, &buf, bufcap);
        buf[len] = 0;
        
        expect(strcmp(buf, "1 0 obj\n<< /Key /Value /Key2 1 0 R /Key3 5 0 R >>\n")).to.equal(0);
    });
    
    it(@"should replace ob ref with given array of ob refs", ^{
        // replace Key3 with an array pointing to self and 5 0 R
        PDReferenceRef ref = PDReferenceCreate(5, 0);
        PDArrayRef arr = PDArrayCreateWithCapacity(2);
        PDArrayAppend(arr, ob);
        PDArrayAppend(arr, ref);
        PDRelease(ref);
        PDDictionarySetEntry(dict, "Key3", arr);
        PDRelease(arr);
        
        len = PDObjectGenerateDefinition(ob, &buf, bufcap);
        buf[len] = 0;
        
        expect(strcmp(buf, "1 0 obj\n<< /Key /Value /Key2 1 0 R /Key3 [ 1 0 R 5 0 R ] >>\n")).to.equal(0);
    });
});

SpecEnd

//- (void)testDicts
//{
//    char *test =
//    "<< >>\n"
//    "<< /Key /Value >>\n"
//    "<< /Key [ 1 2 3 ] >>\n"
//    "<< /Key [ 1 9 0 R 2 3 ] >>\n"
//    "<< /X << /Key2 /Value2 >> >>\n"
//    "<< /A (123) >>\n"
//    "<< /Z null >>\n"
//    "<< /B 3 0 R >>\n"
//    "<< /A true >>\n"
//    "<< /B false >>\n"
//    "<< /O [ <abc123> <def456> ] >>\n"
//    "<< /A 19.4 >>\n"
//    "<< /A 194 >>\n"
//    "<< /A [ 19 19.4 (19.4) <1542> ] >>\n"
//    "<< /Key /Value /Key2 [ 1 2 3 ] /X << /Obref 10 0 R /Key2 /Value2 >> /Key3 (123) /Key4 null /Key5 << /Key false /O [ <abc123> <def456> ] /A 19.4 /B 194 >> /R 0 >>\n"
//    ;
//    
//    PDScannerRef scn = PDScannerCreateWithState(arbStream);
//    PDScannerAttachFixedSizeBuffer(scn, test, strlen(test));
//    
//    PDDictionaryRef dict;
//    pd_stack stk;
//    PDInteger bufcap = strlen(test) * 2;
//    PDInteger bufoffs = 0;
//    char *buf = malloc(bufcap);
//    
//    while (PDScannerPopStack(scn, &stk)) {
//        dict = PDInstanceCreateFromComplex(&stk);
//        bufoffs = PDDictionaryPrinter(dict, &buf, bufoffs, &bufcap);
//        buf[bufoffs++] = '\n';
//    }
//    buf[bufoffs] = 0;
//    XCTAssertTrue(0 == strcmp(buf, test), @"%s cmp fail", buf);
//}
//
//- (void)testArrays
//{
//    char *test =
//    "[ ]\n"
//    "[ 1 ]\n"
//    "[ 1 2 ]\n"
//    "[ 1 0 R ]\n"
//    "[ 2 1 0 R ]\n"
//    "[ 2 1 0 R 3 ]\n"
//    "[ /Name ]\n"
//    "[ /Name /Name2 ]\n"
//    "[ << /Key /Value >> ]\n"
//    "[ /Name << /Key /Value >> ]\n"
//    "[ 1 << /Key (2) >> ]\n"
//    "[ [ 1 2 ] 3 4 [ 5 [ 6 7 [ 8 [ [ 9 ] ] ] 10 ] ] 11 12 ]\n"
//    "[ <abc> (123) 456 /Hopp ]\n"
//    ;
//    
//    PDScannerRef scn = PDScannerCreateWithState(pdfRoot);
//    PDScannerAttachFixedSizeBuffer(scn, test, strlen(test));
//    
//    PDArrayRef arr;
//    pd_stack stk;
//    PDInteger bufcap = strlen(test) * 2;
//    PDInteger bufoffs = 0;
//    char *buf = malloc(bufcap);
//    
//    while (PDScannerPopStack(scn, &stk)) {
//        arr = PDInstanceCreateFromComplex(&stk);
//        bufoffs = PDArrayPrinter(arr, &buf, bufoffs, &bufcap);
//        buf[bufoffs++] = '\n';
//    }
//    buf[bufoffs] = 0;
//    XCTAssertTrue(0 == strcmp(buf, test), @"%s cmp fail", buf);
//}
//
//- (void)testNumericNames
//{
//    // << /I53 53 0 R /I53 53 0 R >> would break; Pajdeg would set up a dictionary with two separate keys with the same string and the former would print out as emptiness, which would give
//    // << /I53  /I53 53 0 R >>; this would be interpreted as "the entry /I53 with the value /I53, followed by ???????*boom*"
//    
//    char *test =
//    "<</I53 53 0 R/I53 53 0 R>>\n"
//    "true\n"
//    ;
//    char *result =
//    "<< /I53 53 0 R >>\n"
//    ;
//    
//    PDScannerRef scn = PDScannerCreateWithState(pdfRoot);
//    PDScannerAttachFixedSizeBuffer(scn, test, strlen(test));
//    
//    PDDictionaryRef dict;
//    pd_stack stk;
//    PDInteger bufcap = strlen(result) * 2;
//    PDInteger bufoffs = 0;
//    char *buf = malloc(bufcap);
//    
//    XCTAssertTrue(PDScannerPopStack(scn, &stk), @"failed to pop dict");
//    dict = PDInstanceCreateFromComplex(&stk);
//    bufoffs = PDDictionaryPrinter(dict, &buf, bufoffs, &bufcap);
//    buf[bufoffs++] = '\n';
//    
//    buf[bufoffs] = 0;
//    XCTAssertTrue(0 == strcmp(buf, result), @"%s cmp fail", buf);
//}
//
//
//- (void)testObjects
//{
//    PDInteger bufcap = 128;
//    char *buf = malloc(bufcap);
//    
//    char *test =
//    "1 0 obj\n"
//    "123\n"
//    "2 0 obj\n"
//    "true\n"
//    "3 0 obj\n"
//    "3.1415\n"
//    "4 0 obj\n"
//    "false\n"
//    "5 0 obj\n"
//    "(regstr)\n"
//    "6 0 obj\n"
//    "<abcd1234>\n"
//    "7 0 obj\n"
//    "/Name\n"
//    "8 0 obj\n"
//    "null\n"
//    "9 0 obj\n"
//    "[ 1 (2) ]\n"
//    "10 0 obj\n"
//    "<< /Name     (kalle)\n"
//    "   /ShoeSize 63.1 >>\n"
//    ;
//    
//    PDScannerRef scn = PDScannerCreateWithState(pdfRoot);
//    PDScannerAttachFixedSizeBuffer(scn, test, strlen(test));
//    
//    void *val;
//    BOOL popBool;
//    PDObjectRef ob;
//    pd_stack stk;
//    PDInteger len;
//    PDInteger oid = 0;
//    const char *ccstr;
//    //    char *cstr;
//    
//#define next(sstr, fstr, init...) \
//oid++;\
//PDScannerPopStack(scn, &stk); \
//pd_stack_destroy(&stk); \
//popBool = YES;\
//init; \
//if (popBool) { \
//XCTAssertTrue(0 == strncmp(ccstr, sstr, strlen(sstr)), @"%s cmp fail", ccstr); \
//\
//len = PDObjectGenerateDefinition(ob, &buf, bufcap); \
//buf[len] = 0; \
//XCTAssertTrue(0 == strncmp(buf, fstr, strlen(fstr)), @"%s cmp (full) fail", fstr);\
//PDRelease(ob);\
//}
//    
//#define nextv(sstr, fstr) \
//next(sstr, fstr, \
//XCTAssertTrue(PDScannerPopString(scn, &cstr), @"pop str");\
//ccstr = cstr;\
//ob = PDObjectCreate(oid,0);\
//ob->type = PDObjectTypeString;\
//ob->def = cstr)
//    
//#define nextr(sstr, fstr) \
//next(sstr, fstr, \
//popBool = PDScannerPopStack(scn, &stk);\
//XCTAssertTrue(popBool, @"pop fail"); \
//if (popBool) { \
//val = PDInstanceCreateFromComplex(&stk); \
//len = (*PDInstancePrinters[PDResolve(val)])(val, &buf, 0, &bufcap); \
//buf[len] = 0;\
//ccstr = buf;\
//ob = PDObjectCreateFromDefinitionsStack(oid, stk));\
//}
//    
//    nextr("123", "1 0 obj\n123\n");
//    //    PDScannerPopStack(scn, &stk);
//    //    pd_stack_destroy(&stk);
//    //    XCTAssertTrue(PDScannerPopStack(scn, &stk), @"pop fail");
//    //    ob = PDObjectCreateFromDefinitionsStack(1, stk);
//    //    ccstr = PDObjectGetValue(ob);
//    //    XCTAssertTrue(0 == strcmp(ccstr, "123"), @"cmp fail");
//    //    
//    //    PDInteger len = PDObjectGenerateDefinition(ob, &buf, bufcap);
//    //    buf[len] = 0;
//    //    XCTAssertTrue(0 == strcmp(buf, "1 0 obj\n123\n"), @"cmp fail");
//    
//    nextr("true", "2 0 obj\ntrue\n");
//    nextr("3.1415", "3 0 obj\n3.1415\n");
//    nextr("false", "4 0 obj\nfalse\n");
//    nextr("(regstr)", "5 0 obj\n(regstr)\n");
//    nextr("<abcd1234>", "6 0 obj\n<abcd1234>\n");
//    nextr("/Name", "7 0 obj\n/Name\n");
//    nextr("null", "8 0 obj\nnull\n");
//    nextr("[ 1 (2) ]", "9 0 obj\n[ 1 (2) ]\n");
//    nextr("<< /Name (kalle) /ShoeSize 63.1 >>", "10 0 obj\n<< /Name (kalle) /ShoeSize 63.1 >>\n");
//    //    "5 0 obj\n"
//    //    "(regstr)\n"
//    //    "6 0 obj\n"
//    //    "<abcd1234>\n"
//    //    "7 0 obj\n"
//    //    "/Name\n"
//    //    "8 0 obj\n"
//    //    "null\n"
//    //    "9 0 obj\n"
//    //    "[ 1 (2) ]\n"
//    //    "10 0 obj\n"
//    //    "<< /Name     (kalle)\n"
//    //    "   /ShoeSize 63.1 >>\n"
//    //    ;
//}
//
//- (void)testNumbers
//{
//    PDReal real;
//    PDBool boolean;
//    pd_stack stk;
//    PDNumberRef num;
//    char *cstr;
//    
//    PDInteger bufcap = 128;
//    char *buf = malloc(bufcap);
//    
//    char *test =
//    "123\n"
//    "true\n"
//    "3.1415\n"
//    "false\n"
//    "null\n";
//    
//    PDScannerRef scn = PDScannerCreateWithState(arbStream);
//    PDScannerAttachFixedSizeBuffer(scn, test, strlen(test));
//    PDInteger len;
//    
//    //
//    // pop next object; it should be a number, integer type, 123
//    //
//    
//    XCTAssertTrue(PDScannerPopStack(scn, &stk), @"pop stack failed");
//    num = PDInstanceCreateFromComplex(&stk);
//    pd_stack_destroy(&stk);
//    XCTAssertTrue(NULL != num, @"null number");
//    XCTAssertEqual(PDInstanceTypeNumber, PDResolve(num), @"type failure");
//    XCTAssertEqual(PDObjectTypeInteger, num->type, @"number type failure");
//    
//    len = PDNumberGetInteger(num);
//    XCTAssertEqual((PDInteger)123, len, @"number fail");
//    
//    // print object; result should be number without wrapping
//    len = PDNumberPrinter(num, &buf, 0, &bufcap);
//    buf[len] = 0;
//    XCTAssertTrue(0 == strcmp(buf, "123"), @"printer failure");
//    
//    PDRelease(num);
//    
//    //
//    // pop next object; it should be a number, bool type, true
//    //
//    
//    XCTAssertTrue(PDScannerPopStack(scn, &stk), @"pop stack failed");
//    num = PDInstanceCreateFromComplex(&stk); //PDInstanceCreateFromComplex(&stk);
//    XCTAssertTrue(NULL != num, @"null number");
//    XCTAssertEqual(PDInstanceTypeNumber, PDResolve(num), @"type failure");
//    XCTAssertEqual(PDObjectTypeBoolean, num->type, @"number type failure");
//    
//    boolean = PDNumberGetBool(num);
//    XCTAssertEqual((PDBool)true, boolean, @"number fail");
//    
//    // print object; result should be "true" without wrapping
//    len = PDNumberPrinter(num, &buf, 0, &bufcap);
//    buf[len] = 0;
//    XCTAssertTrue(0 == strcmp(buf, "true"), @"printer failure");
//    free(cstr);
//    
//    PDRelease(num);
//    
//    //
//    // pop next object; it should be a number, real type, 3.1415
//    //
//    
//    XCTAssertTrue(PDScannerPopStack(scn, &stk), @"pop stack failed");
//    num = PDInstanceCreateFromComplex(&stk);
//    pd_stack_destroy(&stk);
//    XCTAssertTrue(NULL != num, @"null number");
//    XCTAssertEqual(PDInstanceTypeNumber, PDResolve(num), @"type failure");
//    XCTAssertEqual(PDObjectTypeReal, num->type, @"number type failure");
//    
//    real = PDNumberGetReal(num);
//    XCTAssertEqual((PDReal)3.1415, real, @"number fail");
//    
//    // print object; result should be number without wrapping
//    len = PDNumberPrinter(num, &buf, 0, &bufcap);
//    buf[len] = 0;
//    XCTAssertTrue(0 == strncmp(buf, "3.1415", strlen("3.1415")), @"printer failure");
//    
//    PDRelease(num);
//    
//    //
//    // pop next object; it should be a number, bool type, false
//    //
//    
//    XCTAssertTrue(PDScannerPopStack(scn, &stk), @"pop stack failed");
//    num = PDInstanceCreateFromComplex(&stk); //PDInstanceCreateFromComplex(&stk);
//    XCTAssertTrue(NULL != num, @"null number");
//    XCTAssertEqual(PDInstanceTypeNumber, PDResolve(num), @"type failure");
//    XCTAssertEqual(PDObjectTypeBoolean, num->type, @"number type failure");
//    
//    boolean = PDNumberGetBool(num);
//    XCTAssertEqual((PDBool)false, boolean, @"number fail");
//    
//    // print object; result should be "true" without wrapping
//    len = PDNumberPrinter(num, &buf, 0, &bufcap);
//    buf[len] = 0;
//    XCTAssertTrue(0 == strcmp(buf, "false"), @"printer failure");
//    free(cstr);
//    
//    PDRelease(num);
//    
//    //
//    // pop next object; it should be a number, the null object
//    //
//    
//    XCTAssertTrue(PDScannerPopStack(scn, &stk), @"pop stack failed");
//    num = PDInstanceCreateFromComplex(&stk); //PDInstanceCreateFromComplex(&stk);
//    XCTAssertTrue(NULL != num, @"null number");
//    XCTAssertEqual(PDInstanceTypeNumber, PDResolve(num), @"type failure");
//    XCTAssertEqual(PDObjectTypeBoolean, num->type, @"number type failure");
//    
//    XCTAssertEqual(num, PDNullObject, @"num != null ob");
//    
//    // print object; result should be "true" without wrapping
//    len = PDNumberPrinter(num, &buf, 0, &bufcap);
//    buf[len] = 0;
//    XCTAssertTrue(0 == strcmp(buf, "null"), @"printer failure");
//    free(cstr);
//    
//    PDRelease(num);
//    
//    //
//    //
//    //
//    
//    free(buf);
//    
//    PDRelease(scn);
//}
//
//- (void)testStrings
//{
//    pd_stack stk;
//    PDInteger len;
//    PDStringRef str;
//    const char *cstr;
//    
//    PDInteger bufcap = 128;
//    char *buf = malloc(bufcap);
//    
//    char *test =
//    "(regstr)\n"
//    "<abcd1234>\n"
//    "/Name\n";
//    
//    PDScannerRef scn = PDScannerCreateWithState(arbStream);
//    PDScannerAttachFixedSizeBuffer(scn, test, strlen(test));
//    
//    //
//    // pop first object; it should be a regular (escaped) string "regstr"
//    //
//    
//    XCTAssertTrue(PDScannerPopStack(scn, &stk), @"pop stack failed");
//    str = PDInstanceCreateFromComplex(&stk);
//    pd_stack_destroy(&stk);
//    XCTAssertTrue(NULL != str, @"null string");
//    XCTAssertEqual(PDInstanceTypeString, PDResolve(str), @"type failure");
//    XCTAssertEqual(PDStringTypeEscaped, str->type, @"string type failure");
//    
//    cstr = PDStringEscapedValue(str, false);
//    XCTAssertTrue(0 == strcmp(cstr, "regstr"), @"regstr fail");
//    //    free(cstr);
//    
//    cstr = PDStringEscapedValue(str, true);
//    XCTAssertTrue(0 == strcmp(cstr, "(regstr)"), @"regstr fail");
//    //    free(cstr);
//    
//    // print object; result should be wrapped string
//    len = PDStringPrinter(str, &buf, 0, &bufcap);
//    buf[len] = 0;
//    XCTAssertTrue(0 == strcmp(buf, "(regstr)"), @"printer failure");
//    
//    PDRelease(str);
//    
//    //
//    // pop next object; it should be a hex string "abcd1234"
//    //
//    
//    XCTAssertTrue(PDScannerPopStack(scn, &stk), @"pop stack failed");
//    str = PDInstanceCreateFromComplex(&stk);
//    pd_stack_destroy(&stk);
//    XCTAssertTrue(NULL != str, @"null string");
//    XCTAssertEqual(PDInstanceTypeString, PDResolve(str), @"type failure");
//    XCTAssertEqual(PDStringTypeHex, str->type, @"string type failure");
//    
//    cstr = PDStringHexValue(str, false);
//    XCTAssertTrue(0 == strcmp(cstr, "abcd1234"), @"hexstr fail");
//    //    free(cstr);
//    
//    cstr = PDStringHexValue(str, true);
//    XCTAssertTrue(0 == strcmp(cstr, "<abcd1234>"), @"hexstr fail");
//    //    free(cstr);
//    
//    // print object; result should be wrapped string
//    len = PDStringPrinter(str, &buf, 0, &bufcap);
//    buf[len] = 0;
//    XCTAssertTrue(0 == strcmp(buf, "<abcd1234>"), @"printer failure");
//    
//    PDRelease(str);
//    
//    //
//    // pop next object; it should be a name string "/Name"
//    //
//    
//    XCTAssertTrue(PDScannerPopStack(scn, &stk), @"pop stack failed");
//    str = PDInstanceCreateFromComplex(&stk);
//    pd_stack_destroy(&stk);
//    XCTAssertTrue(NULL != str, @"null string");
//    XCTAssertEqual(PDInstanceTypeString, PDResolve(str), @"type failure");
//    XCTAssertEqual(PDStringTypeName, str->type, @"string type failure");
//    
//    cstr = PDStringNameValue(str, false);
//    XCTAssertTrue(0 == strcmp(cstr, "/Name"), @"regstr fail");
//    //    free(cstr);
//    
//    // print object; result should be unwrapped string and should include slash
//    len = PDStringPrinter(str, &buf, 0, &bufcap);
//    buf[len] = 0;
//    XCTAssertTrue(0 == strcmp(buf, "/Name"), @"printer failure");
//    
//    PDRelease(str);
//    
//    //
//    //    // pop next object; it should be a constant string, null
//    //    //
//    //    
//    //    XCTAssertTrue(PDScannerPopStack(scn, &stk), @"pop stack failed");
//    //    str = PDInstanceCreateFromComplex(&stk); //PDInstanceCreateFromComplex(&stk);
//    //    XCTAssertTrue(NULL != str, @"null number");
//    //    XCTAssertEqual(PDInstanceTypeString, PDResolve(str), @"type failure");
//    //
//    //    cstr = PDStringEscapedValue(str, false);
//    //    XCTAssertTrue(0 == strcmp(cstr, "null"), @"const string fail");
//    //    
//    //    // print object; result should be "true" without wrapping
//    //    len = PDStringPrinter(str, &buf, 0, &bufcap);
//    //    buf[len] = 0;
//    //    XCTAssertTrue(0 == strcmp(buf, "null"), @"printer failure");
//    //    
//    //    PDRelease(str);
//    
//    //
//    //
//    //
//    
//    free(buf);
//    
//    PDRelease(scn);
//}
//
//@end
