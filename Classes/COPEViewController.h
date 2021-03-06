//
//  COPEViewController.h
//  radio3
//
//  Created by Javier Quevedo on 1/8/09.
//  Copyright 2009 Daniel Rodríguez and Javier Quevedo. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <MediaPlayer/MediaPlayer.h>

@class RRQAudioPlayer;
@class COPENeedleView;

@interface COPEViewController : UIViewController {
 @private
	IBOutlet UIButton *controlButton;
	IBOutlet UIView *volumeViewHolder;
	IBOutlet UIImageView *loadingImage;
	IBOutlet UIView *flippableView;
	IBOutlet UILabel *stationLabel;
	IBOutlet UIView *topBar;
	IBOutlet UIView *bottomBar;
  IBOutlet UIView *backgroundView;
  IBOutlet COPENeedleView *needleView;
	
	RRQAudioPlayer *player;
	NSInteger activeRadio;
	NSArray *radiosList;
	NSArray *radiosURLS;	
	
	pthread_mutex_t stopMutex;
	pthread_cond_t stopCondition;	
	
	BOOL isPlaying;
	BOOL interruptedDuringPlayback;
	BOOL flipping;
	BOOL infoViewVisible;
	
	UIImage *playImage;
	UIImage *playHighlightImage;
	UIImage *pauseImage;
	UIImage *pauseHighlightImage;
	UIImage *volumeMinimumTrackImage;
	UIImage *volumeMaximumTrackImage;
	UIImage *volumeThumbImage;
		
	UISlider *volumeSlider;
	UIView *infoView;
	UIView *radiosView;
}

- (IBAction)controlButtonClicked:(UIButton *)button;
- (IBAction)infoButtonClicked:(UIButton *)button;
- (void)saveApplicationState;
- (void)audioSessionInterruption:(UInt32)interruptionState;

@end
