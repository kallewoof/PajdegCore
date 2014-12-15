//
//  PDHashMapTests.m
//  pajdeg
//
//  Created by Karl-Johan Alm on 23/11/14.
//  Copyright (c) 2014 Kalle Alm. All rights reserved.
//

#include "pd_pdf_implementation.h"
#include "PDReference.h"
#include "PDHashMap.h"
#include "PDString.h"

extern PDInteger PDGetRetainCount(void *pajdegObject);

SpecBegin(PDHashMapTests)

#define expectPDStringEquals(a,b) expect(strcmp(PDStringEscapedValue(a, false), PDStringEscapedValue(b, false))).to.equal(0)

describe(@"hash map", ^{
    
    beforeAll(^{
        pd_pdf_implementation_use();
    });
    
    describe(@"creation", ^{
        PDHashMapRef hm = PDHashMapCreate();
        
        afterAll(^{
            PDRelease(hm);
        });
        
        it(@"should not be nil", ^{
            expect(hm).toNot.equal(nil);
        });
        
        it(@"should have 0 items", ^{
            expect(PDHashMapGetCount(hm)).to.equal(0);
        });
    });
    
    describe(@"insertion", ^{
        char *k = "key";
        PDStringRef v = PDStringWithCString(strdup("hello"));
        
        PDHashMapRef hm = PDHashMapCreate();
        
        afterAll(^{
            PDRelease(hm);
        });
        
        PDHashMapSet(hm, k, v);
        PDInteger count = PDHashMapGetCount(hm);
        PDStringRef got = PDRetain(PDHashMapGet(hm, k));
        
        it(@"should have 1 item after insertion", ^{
            expect(count).to.equal(1);
        });
        
        it(@"should return the inserted value", ^{
            expectPDStringEquals(got, v);
            PDRelease(got);
        });
        
        describe(@"replacement", ^{
            PDStringRef v2 = PDRetain(PDStringWithCString(strdup("world")));
            
            PDHashMapSet(hm, k, v2);
            PDInteger count = PDHashMapGetCount(hm);
            PDStringRef got = PDRetain(PDHashMapGet(hm, k));
            
            it(@"should still have 1 item after replacement", ^{
                expect(count).to.equal(1);
            });
            
            it(@"should return the new value", ^{
                expectPDStringEquals(got, v2);
                PDRelease(got);
                PDRelease(v2);
            });
            
            describe(@"many values", ^{
                char *k2 = "key2";
                PDStringRef v3 = PDStringWithCString(strdup("good bye"));
                
                PDHashMapSet(hm, k2, v3);
                PDInteger count = PDHashMapGetCount(hm);
                PDStringRef g1 = PDHashMapGet(hm, k);
                PDStringRef g2 = PDHashMapGet(hm, k2);
                
                it(@"should have 2 items after second insertion", ^{
                    expect(count).to.equal(2);
                });
                
                it(@"should return the new values for keys 1 and 2", ^{
                    expectPDStringEquals(g1, v2);
                    expectPDStringEquals(g2, v3);
                });
            });
        });
    });
    
    
    describe(@"deletion", ^{
        char *k = "key";
        PDStringRef v = PDStringWithCString(strdup("hello"));
        
        PDHashMapRef hm = PDHashMapCreate();
        
        afterAll(^{
            PDRelease(hm);
        });
        
        PDHashMapSet(hm, k, v);
        PDHashMapDelete(hm, k);
        
        it(@"should have 0 items after deletion", ^{
            expect(PDHashMapGetCount(hm)).to.equal(0);
        });
        
        it(@"should return NULL (\"\") for deleted keys", ^{
            expect(PDHashMapGet(hm, k)).to.equal(NULL);
        });
    });
    
    
    describe(@"random", ^{
        //#define norand
#ifdef norand
#   define plus(k,v) k, 1, v
#   define minus(k) k, 0
        PDInteger nonrands[] = {
            plus(26, 48),
            plus(95, 76),
        };
        //72, 0, 30, 1, 80, 56, 0, 77, 1, 67};
        int noranditer = 0;
#   define nextval(min,mod) nonrands[noranditer++]
#else
#   define nextval(min,mod) (min + (arc4random() % mod))
#endif
        
        NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
        PDHashMapRef hm = PDHashMapCreate();
        
        for (int i = 0; i < 1000; i++) {
            PDInteger k = nextval(1, 100);
            NSString *ks = [NSString stringWithFormat:@"%ld", k];
            char *kp = strdup(ks.UTF8String);
            if (nextval(0, 2)) {
                PDInteger v = nextval(1, 100);
                NSString *vs = [NSString stringWithFormat:@"%ld", v];
                PDStringRef vp = PDStringWithCString(strdup(vs.UTF8String));
                //printf("+ %ld = %ld\n", k, v);
                [dict setObject:vs forKey:ks];
                PDHashMapSet(hm, kp, vp);
            } else {
                //printf("- %ld\n", k);
                [dict removeObjectForKey:ks];
                PDHashMapDelete(hm, kp);
            }
        }
        
        PDInteger kcount = PDHashMapGetCount(hm);
        void **keys = malloc(sizeof(void*) * kcount);
        
        PDHashMapPopulateKeys(hm, (void*)keys);
//        printf("[ ");
//        for (PDInteger i = 0; i < kcount; i++) 
//            printf(" %ld=%ld", (PDInteger)keys[i], (PDInteger)PDHashMapGet(hm, (PDInteger)keys[i]));
//        printf(" ]\n");
//        printf("< ");
//        for (NSNumber *n in dict) printf(" %ld=%ld", n.longValue, [[dict objectForKey:n] longValue]);
//        printf(" >\n");
        
        it(@"should match the count", ^{
            expect(dict.count).to.equal(PDHashMapGetCount(hm));
        });
        
        it(@"should be identical (dict -> hm)", ^{
            // dict -> hm check
            for (NSString *s in [dict allKeys]) {
                char *ks = strdup(s.UTF8String);
                NSString *v = dict[s];
                PDStringRef vs = PDStringWithCString(strdup(v.UTF8String));
                expectPDStringEquals(vs, PDHashMapGet(hm, ks));
                free(ks);
            }
        });
        
        it(@"should be identical (hm -> dict)", ^{
            // hm -> dict check
            for (PDInteger i = 0; i < kcount; i++) {
                char *ks = keys[i];
                NSString *s = [NSString stringWithUTF8String:ks];
                NSString *v = dict[s];
                PDStringRef vs = PDStringWithCString(strdup(v.UTF8String));
                expectPDStringEquals(vs, PDHashMapGet(hm, ks));
            }
        });
        
        afterAll(^{
            free(keys);
            PDRelease(hm);
        });
    });
});

SpecEnd
