//
//  PDPostScriptTests.m
//  pajdeg
//
//  Created by Karl-Johan Alm on 22/12/14.
//  Copyright (c) 2014 Kalle Alm. All rights reserved.
//

#import <XCTest/XCTest.h>
#import <PajdegCore/Pajdeg.h>
#import <PajdegCore/pd_ps_implementation.h>
#import <PajdegCore/PDCMap.h>

SpecBegin(PDPostScriptTests)

describe(@"base1 (E3.1)", ^{
    // Example 3.1, p. 46 (PLRM.pdf)
    pd_ps_env pse = pd_ps_create();
    char *str = "40 60 add 2 div";
    PDSize len = strlen(str);
    expect(pd_ps_execute_postscript(pse, str, len)).to.beTruthy();
    // Should have (40+60)/2 = 50.0 as topmost object
    PDNumberRef num = pd_ps_get_operand(pse, 0);
    expect(PDResolve(num)).to.equal(PDInstanceTypeNumber);
    PDReal r = PDNumberGetReal(num);
    expect(r).to.beInTheRangeOf(49.9, 50.1);
//    XCTAssertEqualWithAccuracy(r, 50.0, 0.01);
    
    pd_ps_destroy(pse);
});

describe(@"base2 (E3.2)", ^{
    // Example 3.2, p. 48 (PLRM.pdf)
    pd_ps_env pse = pd_ps_create();
    char *str = ("/average {add 2 div} def\n"
                 "40 60 average");
    PDSize len = strlen(str);
    expect(pd_ps_execute_postscript(pse, str, len)).to.beTruthy();
    // Should have (40+60)/2 = 50.0 as topmost object
    PDNumberRef num = pd_ps_get_operand(pse, 0);
    if (PDResolve(num) != PDInstanceTypeNumber) {
        expect(0).to.equal(1);
        return;
    }
    PDReal r = PDNumberGetReal(num);
    expect(r).to.beInTheRangeOf(49.9, 50.1);
    
    pd_ps_destroy(pse);
});

describe(@"base3 (E3.3)", ^{
    // Example 3.3, p. 49 (PLRM.pdf)
    pd_ps_env pse = pd_ps_create();
    char *str = ("/a 4 def\n"
                 "/b 5 def\n"
                 "a b gt {a} {b} ifelse");
    PDSize len = strlen(str);
    expect(pd_ps_execute_postscript(pse, str, len)).to.beTruthy();
    // Should have 5 as topmost object
    PDNumberRef num = pd_ps_get_operand(pse, 0);
    if (PDResolve(num) != PDInstanceTypeNumber) {
        expect(0).to.equal(1);
        return;
    }
    PDInteger i = PDNumberGetInteger(num);
    expect(i).to.equal(5);
    
    pd_ps_destroy(pse);
});

describe(@"toUnicode CMap (1)", ^{
    pd_ps_env pse = pd_ps_create();
    char *str = ("/CIDInit /ProcSet findresource begin 12 dict begin begincmap /CIDSystemInfo <<\n"
                 "/Registry (LMGNKA+TT4+0) /Ordering (T42UV) /Supplement 0 >> def\n"
                 "/CMapName /LMGNKA+TT4+0 def\n"
                 "/CMapType 2 def\n"
                 "1 begincodespacerange <030d> <39e6> endcodespacerange\n"
                 "8 beginbfchar\n"
                 "<030d> <201D>\n"
                 "<14b0> <5F53>\n"
                 "<1702> <62C5>\n"
                 "<19c1> <6728>\n"
                 "<21b5> <7537>\n"
                 "<2472> <79C0>\n"
                 "<32c8> <9234>\n"
                 "<39e6> <FF1A>\n"
                 "endbfchar\n"
                 "endcmap CMapName currentdict /CMap defineresource pop end end\n");
    PDSize len = strlen(str);
    expect(pd_ps_execute_postscript(pse, str, len)).to.beTruthy();
    
    // the above will have resulted in a new resource, so we want to execute a findresource command
    str = ("/LMGNKA+TT4+0 /CMap findresource");
    len = strlen(str);
    expect(pd_ps_execute_postscript(pse, str, len)).to.beTruthy();
    
    PDDictionaryRef dict = pd_ps_get_operand(pse, 0);
    // should be right type
    expect(PDResolve(dict)).to.equal(PDInstanceTypeDict);
    
    // should have a CIDSystemInfo entry
    PDDictionaryRef sysInfo = PDDictionaryGet(dict, "CIDSystemInfo");
    expect(sysInfo).toNot.equal(NULL);
    
    // should have CMapName, CMapType; latter should be a number, and should be 2 as this is ToUnicode
    expect(NULL != PDDictionaryGet(dict, "CMapName")).to.beTruthy();
    expect(PDNumberGetInteger(PDDictionaryGet(dict, "CMapType")) == 2).to.beTruthy();
    
    // it should have a CMap
    PDCMapRef cmap = PDDictionaryGet(dict, "#cmap#");
    expect(NULL != cmap).to.beTruthy();
    
    // should grab a string from the actual PDF where this was pulled from instead of the gook example below
    // CMap should map the UTF16BE string <0123 030d 0234 2472> to <0123 201d 0234 79c0>
    PDStringRef hexStr = PDStringCreateWithHexString(strdup("0123030d02342472"));
    PDStringRef mapped = PDCMapApply(cmap, hexStr);
    PDStringRef matchStr = PDStringCreateWithHexString(strdup("0123201d023479c0"));
    expect(PDStringEqualsString(matchStr, mapped)).to.beTruthy();
    PDRelease(hexStr);
    PDRelease(matchStr);
    
    pd_ps_destroy(pse);
});

describe(@"toUnicode CMap (2)", ^{
    pd_ps_env pse = pd_ps_create();
    char *str = ("/CIDInit /ProcSet findresource begin 12 dict begin begincmap /CIDSystemInfo <<\n"
                 "/Registry (TT9+0) /Ordering (T42UV) /Supplement 0 >> def\n"
                 "/CMapName /TT9+0 def\n"
                 "/CMapType 2 def\n"
                 "1 begincodespacerange <0012> <0020> endcodespacerange\n"
                 "2 beginbfchar\n"
                 "<0012> <03B8>\n"
                 "<0020> <03BC>\n"
                 "endbfchar\n"
                 "endcmap CMapName currentdict /CMap defineresource pop end end\n"
                 "/CIDInit /ProcSet findresource begin 12 dict begin begincmap /CIDSystemInfo <<\n"
                 "/Registry (TT15+0) /Ordering (T42UV) /Supplement 0 >> def\n"
                 "/CMapName /TT15+0 def\n"
                 "/CMapType 2 def\n"
                 "1 begincodespacerange <0009> <0009> endcodespacerange\n"
                 "1 beginbfchar\n"
                 "<0009> <2217>\n"
                 "endbfchar\n"
                 "endcmap CMapName currentdict /CMap defineresource pop end end");
    PDSize len = strlen(str);
    expect(pd_ps_execute_postscript(pse, str, len)).to.beTruthy();
    
    // the above will have resulted in a new resource, so we want to execute a findresource command
    str = ("/TT9+0 /CMap findresource /TT15+0 /CMap findresource");
    len = strlen(str);
    expect(pd_ps_execute_postscript(pse, str, len)).to.beTruthy();
    
    PDDictionaryRef dict15 = pd_ps_get_operand(pse, 0);
    PDDictionaryRef dict9  = pd_ps_get_operand(pse, 1);
    // should be right type
    expect(PDResolve(dict15) == PDInstanceTypeDict).to.beTruthy();
    expect(PDResolve(dict9) == PDInstanceTypeDict).to.beTruthy();
    
    // should have a CIDSystemInfo entry
    PDDictionaryRef sysInfo15 = PDDictionaryGet(dict15, "CIDSystemInfo");
    PDDictionaryRef sysInfo9 = PDDictionaryGet(dict9, "CIDSystemInfo");
    expect(NULL != sysInfo15).to.beTruthy();
    expect(NULL != sysInfo9).to.beTruthy();
    
    // should have CMapName, CMapType; latter should be a number, and should be 2 as this is ToUnicode
    expect(NULL != PDDictionaryGet(dict15, "CMapName")).to.beTruthy();
    expect(PDNumberGetInteger(PDDictionaryGet(dict15, "CMapType")) == 2).to.beTruthy();
    expect(NULL != PDDictionaryGet(dict9, "CMapName")).to.beTruthy();
    expect(PDNumberGetInteger(PDDictionaryGet(dict9, "CMapType")) == 2).to.beTruthy();
    
    // it should have a CMap
    PDCMapRef cmap15 = PDDictionaryGet(dict15, "#cmap#");
    expect(NULL != cmap15).to.beTruthy();
    PDCMapRef cmap9 = PDDictionaryGet(dict9, "#cmap#");
    expect(NULL != cmap9).to.beTruthy();
    
    // should grab a string from the actual PDF where this was pulled from instead of the gook example below
    // CMap 9 should map the UTF16BE string <0012 0020 0112> to <03B8 03BC 0112>
    // CMap 15 should map the UTF16BE string <0008 0009 000A> to <0008 2217 000A>
    PDStringRef hexStr15 = PDStringCreateWithHexString(strdup("00080009000A"));
    PDStringRef hexStr9 = PDStringCreateWithHexString(strdup("001200200112"));
    PDStringRef mapped15 = PDCMapApply(cmap15, hexStr15);
    PDStringRef mapped9 = PDCMapApply(cmap9, hexStr9);
    PDStringRef matchStr15 = PDStringCreateWithHexString(strdup("00082217000A"));
    PDStringRef matchStr9 = PDStringCreateWithHexString(strdup("03B803BC0112"));
    expect(PDStringEqualsString(matchStr15, mapped15)).to.beTruthy();
    expect(PDStringEqualsString(matchStr9, mapped9)).to.beTruthy();
    PDRelease(hexStr15);
    PDRelease(matchStr15);
    PDRelease(hexStr9);
    PDRelease(matchStr9);
    
    pd_ps_destroy(pse);
});

describe(@"toUnicode CMap with BF range", ^{
    pd_ps_env pse = pd_ps_create();
    char *str = ("/CIDInit /ProcSet findresource begin 12 dict begin begincmap /CIDSystemInfo <<\n"
                 "/Registry (TT1+0) /Ordering (T42UV) /Supplement 0 >> def\n"
                 "/CMapName /TT1+0 def\n"
                 "/CMapType 2 def\n"
                 "1 begincodespacerange <079f> <39e6> endcodespacerange\n"
                 "13 beginbfchar\n"
                 "<1515> <5FDC>\n"
                 "<18b1> <6599>\n"
                 "<1a06> <6790>\n"
                 "<2024> <7279>\n"
                 "<21aa> <7528>\n"
                 "<26d4> <7D71>\n"
                 "<27f5> <7FA9>\n"
                 "<2e03> <89E3>\n"
                 "<2e18> <8A08>\n"
                 "<2eb0> <8AD6>\n"
                 "<2ee0> <8B1B>\n"
                 "<2f97> <8CC7>\n"
                 "<39e6> <FF1A>\n"
                 "endbfchar\n"
                 "1 beginbfrange\n"
                 "<079f> <07a0> <300C>\n"
                 "endbfrange\n"
                 "endcmap CMapName currentdict /CMap defineresource pop end end");
    PDSize len = strlen(str);
    expect(pd_ps_execute_postscript(pse, str, len)).to.beTruthy();
    
    // the above will have resulted in a new resource, so we want to execute a findresource command
    str = ("/TT1+0 /CMap findresource");
    len = strlen(str);
    expect(pd_ps_execute_postscript(pse, str, len)).to.beTruthy();
    
    PDCMapRef cmap = PDDictionaryGet(pd_ps_get_operand(pse, 0), "#cmap#");
    expect(NULL != cmap).to.beTruthy();
    
    // we are testing the bfrange part here; presumably, 079f..07a0 should map to 300c..300d
    PDStringRef hexStr = PDStringCreateWithHexString(strdup("078e079f07a007a12e03"));
    PDStringRef mapped = PDCMapApply(cmap, hexStr);
    PDStringRef matchStr = PDStringCreateWithHexString(strdup("078e300c300d07a189e3"));
    expect(PDStringEqualsString(matchStr, mapped)).to.beTruthy();
    PDRelease(hexStr);
    PDRelease(matchStr);
    
    pd_ps_destroy(pse);
});

SpecEnd
