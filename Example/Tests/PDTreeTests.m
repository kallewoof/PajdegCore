//
//  PDTreeTests.m
//  pajdeg
//
//  Created by Karl-Johan Alm on 25/07/14.
//  Copyright (c) 2014 Kalle Alm. All rights reserved.
//

#include "pd_pdf_implementation.h"
#include "PDReference.h"
#include "PDSplayTree.h"

extern PDInteger PDGetRetainCount(void *pajdegObject);

static int deallocations = 0;
static void *last_dealloc = NULL;

void testDealloc(void *info)
{
    PDInteger rc = PDGetRetainCount(info);
    if (rc == 1) {
        deallocations ++;
        last_dealloc = info;
    }
    PDRelease(info);
}

SpecBegin(PDTreeTests)

describe(@"splay tree", ^{
    
    beforeAll(^{
        pd_pdf_implementation_use();
    });
    
    describe(@"creation", ^{
        PDSplayTreeRef tree = PDSplayTreeCreate();
        
        afterAll(^{
            PDRelease(tree);
        });
        
        it(@"should not be nil", ^{
            expect(tree).toNot.equal(nil);
        });
        
        it(@"should have 0 items", ^{
            expect(PDSplayTreeGetCount(tree)).to.equal(0);
        });
    });
    
    describe(@"insertion", ^{
        char *v = "hello";
        
        PDSplayTreeRef tree = PDSplayTreeCreate();
        
        afterAll(^{
            PDRelease(tree);
        });
        
        PDSplayTreeInsert(tree, 123, v);
        
        it(@"should have 1 item after insertion", ^{
            expect(PDSplayTreeGetCount(tree)).to.equal(1);
        });

        it(@"should return the inserted value", ^{
            expect((char*)PDSplayTreeGet(tree, 123)).to.equal(v);
        });
    });
    
    describe(@"deletion", ^{
        char *v = "hello";
        
        PDSplayTreeRef tree = PDSplayTreeCreate();
        
        afterAll(^{
            PDRelease(tree);
        });
        
        PDSplayTreeInsert(tree, 123, v);
        PDSplayTreeDelete(tree, 123);
        
        it(@"should have 0 items after deletion", ^{
            expect(PDSplayTreeGetCount(tree)).to.equal(0);
        });
        
        it(@"should return NULL (\"\") for deleted keys", ^{
            expect((char*)PDSplayTreeGet(tree, 123)).to.equal((char*)NULL);
        });
    });
    
    describe(@"deallocator", ^{
        PDReferenceRef ref = PDReferenceCreate(1, 2);
        
        PDSplayTreeRef vtree = PDSplayTreeCreate();
        PDSplayTreeInsert(vtree, 4, "hello");
        
        PDSplayTreeRef tree = PDSplayTreeCreateWithDeallocator(testDealloc);
        PDSplayTreeInsert(tree, 11, PDRetain(ref));
        PDSplayTreeInsert(tree, 14, PDRetain(vtree));
        
        PDSplayTreeRef TREE = PDSplayTreeCreateWithDeallocator(testDealloc);
        PDSplayTreeInsert(TREE, 1, PDRetain(ref));
        PDSplayTreeInsert(TREE, 2, PDRetain(vtree));
        PDSplayTreeInsert(TREE, 3, PDRetain(tree));
        
        deallocations = 0;

        it(@"should not deallocate ref before its maintainer", ^{
            testDealloc(ref);
            expect(deallocations).to.equal(0);
        });
        
        it(@"should not deallocate vtree prematurely", ^{
            testDealloc(vtree);
            if (deallocations > 0) {
                expect(last_dealloc).toNot.equal(vtree);
            }
        });
        
        it(@"should not dealloc tree prematurely", ^{
            testDealloc(tree);
            if (deallocations > 0) {
                expect(last_dealloc).toNot.equal(tree);
            }
        });
        
        afterAll(^{
            testDealloc(TREE);
            
            it(@"should dealloc all objects", ^{
                expect(deallocations).to.equal(4);
            });
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
        PDSplayTreeRef tree = PDSplayTreeCreate();
        
        for (int i = 0; i < 1000; i++) {
            PDInteger k = nextval(1, 100);
            if (nextval(0, 2)) {
                PDInteger v = nextval(1, 100);
                //printf("+ %ld = %ld\n", k, v);
                [dict setObject:[NSNumber numberWithLong:v] forKey:[NSNumber numberWithLong:k]];
                PDSplayTreeInsert(tree, k, (void*)v);
            } else {
                //printf("- %ld\n", k);
                [dict removeObjectForKey:[NSNumber numberWithLong:k]];
                PDSplayTreeDelete(tree, k);
            }
        }
        
        PDInteger kcount = PDSplayTreeGetCount(tree);
        void **keys = malloc(sizeof(void*) * kcount);
        PDSplayTreePopulateKeys(tree, (void*)keys);
//        printf("[ ");
//        for (PDInteger i = 0; i < kcount; i++) 
//            printf(" %ld=%ld", (PDInteger)keys[i], (PDInteger)PDSplayTreeGet(tree, (PDInteger)keys[i]));
//        printf(" ]\n");
//        printf("< ");
//        for (NSNumber *n in dict) printf(" %ld=%ld", n.longValue, [[dict objectForKey:n] longValue]);
//        printf(" >\n");
        
        it(@"should match the count", ^{
            expect(dict.count).to.equal(PDSplayTreeGetCount(tree));
        });
        
        it(@"should be identical (dict -> tree)", ^{
            // dict -> tree check
            for (NSNumber *n in [dict allKeys]) {
                PDInteger k = [n longValue];
                PDInteger v = [[dict objectForKey:n] longValue];
                expect(v).to.equal((PDInteger)PDSplayTreeGet(tree, k));
            }
        });
        
        it(@"should be identical (tree -> dict)", ^{
            // tree -> dict check
            for (PDInteger i = 0; i < kcount; i++) {
                PDInteger k = (PDInteger)keys[i];
                PDInteger v = (PDInteger)PDSplayTreeGet(tree, k);
                expect(v).to.equal([[dict objectForKey:[NSNumber numberWithLong:k]] longValue]);
            }
        });
        
        afterAll(^{
            free(keys);
            PDRelease(tree);
        });
    });
});

SpecEnd
