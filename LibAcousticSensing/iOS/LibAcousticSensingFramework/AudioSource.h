//
//  AudioSource.h
//  LibAcousticSensingFramework
//
//  Created by Yu-Chih on 5/30/17.
//  Copyright © 2017 Yu-Chih. All rights reserved.
//

#ifndef AudioSource_h
#define AudioSource_h

#import <Foundation/Foundation.h>

@interface AudioSource : NSObject {
    
}
@property int FS;
@property int chCnt;
@property int repeatCnt;
@property (retain, nonatomic) NSData* preamble;
@property (retain, nonatomic) NSData* signal;

-(id) initWithFS:(int) FS andChCnt:(int) chCnt andRepeatCnt:(int) repeatCnt andPreamble: (NSData*) preamble andSignal: (NSData*) signal;
@end

#endif /* AudioSource_h */