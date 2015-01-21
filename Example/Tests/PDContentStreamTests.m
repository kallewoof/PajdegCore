//
//  PDContentStreamTests.m
//  pajdeg
//
//  Created by Karl-Johan Alm on 22/12/14.
//  Copyright (c) 2014 Kalle Alm. All rights reserved.
//

#import "pd_pdf_implementation.h"
#import "Pajdeg.h"
#import "PDCatalog.h"
#import "PDPage.h"
#import "PDContentStreamTextExtractor.h"

SpecBegin(PDContentStreamTests)

__block NSFileManager *_fm = [NSFileManager defaultManager];
__block PDPipeRef _pipe = NULL;

pd_pdf_implementation_use();

afterAll(^{
    if (_pipe) {
        PDRelease(_pipe);
        _pipe = nil;
    }
    pd_pdf_implementation_discard();
});

void (^configIn)(NSString *file_in, NSString *file_out) = ^(NSString *file_in, NSString *file_out) {
    if (_pipe) {
        PDRelease(_pipe);
    }
    
    expect(file_in).toNot.beNil();
    expect(file_out).toNot.beNil();
    
    _fm = [NSFileManager defaultManager];
    expect([_fm fileExistsAtPath:file_in]).to.beTruthy();
    [_fm createDirectoryAtPath:NSTemporaryDirectory() withIntermediateDirectories:YES attributes:nil error:nil];
    [_fm removeItemAtPath:file_out error:NULL];
    
    _pipe = PDPipeCreateWithFilePaths([file_in cStringUsingEncoding:NSUTF8StringEncoding], [file_out cStringUsingEncoding:NSUTF8StringEncoding]);
    
    expect(_pipe).toNot.beNil();
    if (! _pipe) {
        NSLog(@"PDPipeCreateWithFilePaths(\n\t%@\n\t%@\n)", file_in, file_out);
        assert(0);
    }
    
};

//----------------------------------------------------------------

describe(@"text extraction (japanese)", ^{
    it(@"should config", ^{
        NSString *file_in  = [[NSBundle bundleForClass:self.class] pathForResource:@"Japanese" ofType:@"pdf"];
        configIn(file_in, @"/dev/null");
    });
    
    __block PDPageRef page = NULL;
    __block PDParserRef parser = NULL;
    __block PDObjectRef contentsOb = nil;
    
    it(@"should fetch page", ^{
        parser = PDPipeGetParser(_pipe);
        PDCatalogRef catalog = PDParserGetCatalog(parser);
        expect(catalog).toNot.beNil();
        if (catalog) {
            PDInteger obid = PDCatalogGetObjectIDForPage(catalog, 1);
            PDObjectRef pageOb = PDParserLocateAndCreateObject(parser, obid, true);
            char *buf = malloc(64);
            PDInteger cap = 64;
            PDObjectGenerateDefinition(pageOb, &buf, cap);
            printf("page object = %s", buf);
            free(buf);
            page = PDPageCreateWithObject(parser, pageOb);
            expect(page).toNot.beNil();
        }
    });
    
    it(@"should fetch contents", ^{
        PDInteger count = PDPageGetContentsObjectCount(page);
        expect(count).to.beGreaterThan(0);
        if (count > 0) {
            contentsOb = PDPageGetContentsObjectAtIndex(page, 0);
            char *contentStream = PDParserLocateAndFetchObjectStreamForObject(parser, contentsOb);
            expect(contentStream).toNot.beNil();
        }
    });
    
    it(@"should extract text", ^{
        expect(contentsOb).toNot.beNil();
        if (contentsOb) {
            char *buf;
            PDContentStreamRef te = PDContentStreamCreateTextExtractor(page, &buf);
            PDContentStreamExecute(te, contentsOb);
            expect(buf).toNot.beNil();
        }
    });
});

SpecEnd
