//
//  AcousticSensingControllerCallerDelegate.h
//  LibAcousticSensingFramework
//
//  Created by Yu-Chih on 2/6/17.
//  Copyright © 2017 Yu-Chih. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol AcousticSensingControllerCallerDelegate <NSObject>
- (void)unexpectedEnd:(int) code withReason: (NSString *) reason;
@end