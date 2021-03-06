//
//  SFBill.m
//  Congress
//
//  Created by Daniel Cloud on 1/8/13.
//  Copyright (c) 2013 Sunlight Foundation. All rights reserved.
//

#import "SFBill.h"
#import "SFBillAction.h"
#import "SFLegislator.h"
#import "SFCongressURLService.h"
#import "SFDateFormatterUtil.h"
#import "SFBillTypeTransformer.h"
#import "SFBillIdTransformer.h"

@implementation SFBill
{
    NSString *_displayBillType;
    NSString *_displayName;
}

static NSMutableArray *_collection = nil;

@synthesize lastActionAtIsDateTime = _lastActionAtIsDateTime;

#pragma mark - initWithDictionary

- (instancetype)initWithDictionary:(NSDictionary *)dictionaryValue error:(NSError **)error
{
    self = [super initWithDictionary:dictionaryValue error:error];
    NSString *lastActionAtRaw = [dictionaryValue valueForKeyPath:@"last_action_at"];
    _lastActionAtIsDateTime = ([lastActionAtRaw length] == 10) ? NO :YES;
    return self;
}

#pragma mark - MTLModel Versioning

+ (NSUInteger)modelVersion {
    return 2;
}

#pragma mark - MTLModel Transformers

+ (NSDictionary *)JSONKeyPathsByPropertyKey {
    return @{
            @"billId": @"bill_id",
            @"billType": @"bill_type",
            @"shortTitle": @"short_title",
            @"officialTitle": @"official_title",
            @"shortSummary": @"summary_short",
            @"sponsorId": @"sponsor_id",
            @"cosponsorIds": @"cosponsor_ids",
            @"introducedOn": @"introduced_on",
            @"lastAction": @"last_action",
            @"lastActionAt": @"last_action_at",
            @"lastPassageVoteAt": @"last_passage_vote_at",
            @"lastVoteAt": @"last_vote_at",
            @"housePassageResultAt": @"house_passage_result_at",
            @"senatePassageResultAt": @"senate_passage_result_at",
            @"vetoedAt": @"vetoed_at",
            @"houseOverrideResultAt": @"house_override_result_at",
            @"senateOverrideResultAt": @"senate_override_result_at",
            @"senateClotureResultAt": @"senate_cloture_result_at",
            @"awaitingSignatureSince": @"awaiting_signature_since",
            @"enactedAt": @"enacted_at",
            @"housePassageResult": @"house_passage_result",
            @"senatePassageResult": @"senate_passage_result",
            @"houseOverrideResult": @"house_override_result",
            @"senateOverrideResult": @"senate_override_result",
    };
}

+ (NSValueTransformer *)officialTitleJSONTransformer {
    return [MTLValueTransformer transformerWithBlock:^id(NSString *str) {
        NSArray *stringComponents = [str componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
        return [stringComponents componentsJoinedByString:@" "];
    }];
}

+ (NSValueTransformer *)shortTitleJSONTransformer {
    return [MTLValueTransformer transformerWithBlock:^id(NSString *str) {
        NSArray *stringComponents = [str componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
        return [stringComponents componentsJoinedByString:@" "];
    }];
}

+ (NSValueTransformer *)lastActionAtJSONTransformer {
    return [MTLValueTransformer reversibleTransformerWithForwardBlock:^(NSString *str) {
        if ([str length] == 10) {
            return [[SFDateFormatterUtil ISO8601DateOnlyFormatter] dateFromString:str];
        }
        return [[SFDateFormatterUtil ISO8601DateTimeFormatter] dateFromString:str];
    } reverseBlock:^(NSDate *date) {
        return [[SFDateFormatterUtil ISO8601DateTimeFormatter] stringFromDate:date];
    }];
}

+ (NSValueTransformer *)lastVoteAtJSONTransformer {
    return [MTLValueTransformer reversibleTransformerWithForwardBlock:^(NSString *str) {
        if ([str length] == 10) {
            return [[SFDateFormatterUtil ISO8601DateOnlyFormatter] dateFromString:str];
        }
        return [[SFDateFormatterUtil ISO8601DateTimeFormatter] dateFromString:str];
    } reverseBlock:^(NSDate *date) {
        return [[SFDateFormatterUtil ISO8601DateTimeFormatter] stringFromDate:date];
    }];
}

+ (NSValueTransformer *)introducedOnJSONTransformer {
    return [MTLValueTransformer reversibleTransformerWithForwardBlock:^(NSString *str) {
        return [[SFDateFormatterUtil ISO8601DateOnlyFormatter] dateFromString:str];
    } reverseBlock:^(NSDate *date) {
        return [[SFDateFormatterUtil ISO8601DateOnlyFormatter] stringFromDate:date];
    }];
}

+ (NSValueTransformer *)actionsJSONTransformer {
    return [NSValueTransformer mtl_JSONArrayTransformerWithModelClass:[SFBillAction class]];
}

+ (NSValueTransformer *)lastActionJSONTransformer {
    return [NSValueTransformer mtl_JSONDictionaryTransformerWithModelClass:[SFBillAction class]];
}


+ (NSValueTransformer *)cosponsorIdsJSONTransformer
{
    return [MTLValueTransformer reversibleTransformerWithBlock:^id(id idArr) {
        return idArr;
    }];
}

+ (NSValueTransformer *)sponsorJSONTransformer
{
    return [NSValueTransformer mtl_JSONDictionaryTransformerWithModelClass:[SFLegislator class]];
}

#pragma mark - SynchronizedObject protocol methods

+(NSString *)__remoteIdentifierKey
{
    return @"billId";
}

+(NSMutableArray *)collection;
{
    if (_collection == nil) {
        _collection = [NSMutableArray array];
    }
    return _collection;
}

#pragma mark - SFBill

-(NSString *)displayBillType
{
    if (!_displayBillType) {
        _displayBillType = [[NSValueTransformer valueTransformerForName:SFBillTypeTransformerName] transformedValue:self.billType];
    }
    return _displayBillType;
}

-(NSString *)displayName
{
    if (!_displayName) {
        _displayName = [[NSValueTransformer valueTransformerForName:SFBillIdTransformerName] transformedValue:self.billId];
    }
    return _displayName;
}

-(NSArray *)actionsAndVotes
{
    NSMutableArray *combinedObjects = [NSMutableArray array];
    [combinedObjects addObjectsFromArray:self.actions];
    [combinedObjects addObjectsFromArray:self.rollCallVotes];
    [combinedObjects sortUsingComparator:^NSComparisonResult(id obj1, id obj2) {
        Class billActionClass = [SFBillAction class];
        NSDate *obj1Date = [obj1 isKindOfClass:billActionClass] ? [obj1 valueForKey:@"actedAt"] :  [obj1 valueForKey:@"votedAt"];
        NSDate *obj2Date = [obj2 isKindOfClass:billActionClass] ? [obj2 valueForKey:@"actedAt"] :  [obj2 valueForKey:@"votedAt"];
        NSTimeInterval dateDifference = [obj1Date timeIntervalSinceDate:obj2Date];
        if (dateDifference < 0) {
            return NSOrderedDescending;
        }
        else if (dateDifference > 0) {
            return NSOrderedAscending;
        }
        return NSOrderedSame;
    }];
    return combinedObjects;
}

-(NSURL *)shareURL
{
    return [SFCongressURLService landingPageforBillWithId:self.billId];
}

@end
