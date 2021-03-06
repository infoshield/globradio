//
//  FIViewController.m
//  radio3
//
//  Created by Daniel Rodríguez Troitiño on 25/12/08.
//  Copyright 2008 Daniel Rodríguez and Javier Quevedo. All rights reserved.
//

#import "FIViewController.h"
#import "RRQShoutcastAudioPlayer.h"
#import "RRQReachability.h"
#import "FIAlbumView.h"
#import "FILastFMDataProvider.h"
#import "RRQVolumeView.h"

NSString *kFIFMRadioURL = @"http://radio.asoc.fi.upm.es:8000/";
// NSString *kFIFMRadioURL = @"http://scfire-mtc-aa05.stream.aol.com:80/stream/1074";

NSString *kDefaultTitle = @"Radio FI-FM";
NSString *kDefaultArtist = @"http://radio.asoc.fi.upm.es/";

@interface FIViewController ()

@property (nonatomic, retain) UIImage *playImage;
@property (nonatomic, retain) UIImage *playHighlightImage;
@property (nonatomic, retain) UIImage *pauseImage;
@property (nonatomic, retain) UIImage *pauseHighlightImage;
@property (nonatomic, retain) UIImage *albumArtDefaultImage;

- (void)stopRadio;

- (void)playRadio;
- (void)privatePlayRadio;

- (void)showNetworkProblemsAlert;

- (void)reachabilityChanged:(NSNotification *)notification;

- (void)changeTrackTitle:(NSString *)newTitle;
- (void)changeTrackArtist:(NSString *)newArtist;

@end

@implementation FIViewController

@synthesize playImage;
@synthesize playHighlightImage;
@synthesize pauseImage;
@synthesize pauseHighlightImage;
@synthesize albumArtDefaultImage;

#pragma mark IBActions

- (IBAction)controlButtonClicked:(UIButton *)button {
  if (isPlaying) {
    [self stopRadio];
  } else {
    [self playRadio];
  }
}

#pragma mark Custom methods

- (void)audioSessionInterruption:(UInt32)interruptionState {
  RNLog(@"audioSessionInterruption %d", interruptionState);
  if (interruptionState == kAudioSessionBeginInterruption) {
    RNLog(@"AudioSessionBeginInterruption");
    BOOL playing = isPlaying;
    [self stopRadio];
    OSStatus status = AudioSessionSetActive(false);
    if (status) { RNLog(@"AudioSessionSetActive err %d", status); }
    interruptedDuringPlayback = playing;
  } else if (interruptionState == kAudioSessionEndInterruption) {
    RNLog(@"AudioSessionEndInterruption && interruptedDuringPlayback");
    OSStatus status = AudioSessionSetActive(true);
    if (status != kAudioSessionNoError) { RNLog(@"AudioSessionSetActive err %d", status); }
    interruptedDuringPlayback = NO;
  }
}

- (void)reachabilityChanged:(NSNotification *)notification {
  if ([[RRQReachability sharedReachability] remoteHostStatus] == NotReachable) {
    [self showNetworkProblemsAlert];
  }
}

- (void)showNetworkProblemsAlert {
  UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"Problemas de conexión"
                                                      message:@"No es posible conectar a Internet.\nAsegurese de disponer de conexión a Internet."
                                                     delegate:nil
                                            cancelButtonTitle:nil
                                            otherButtonTitles:@"Aceptar", nil];
  [alertView show];
  [alertView release];
}

- (void)stopRadio {
  if (isPlaying) {
    [player stop];
  }
}

- (void)setPlayState {
  controlButton.hidden = NO;
  loadingImage.hidden = YES;
  if (loadingImage.isAnimating)
    [loadingImage startAnimating];
  [controlButton setImage:pauseImage forState:UIControlStateNormal];
  [controlButton setImage:pauseHighlightImage
                 forState:UIControlStateHighlighted];
}

- (void)setStopState {
  controlButton.hidden = NO;
	loadingImage.hidden = YES;
	if (loadingImage.isAnimating)
		[loadingImage stopAnimating];
	[controlButton setImage:playImage forState:UIControlStateNormal];
	[controlButton setImage:playHighlightImage
                 forState:UIControlStateHighlighted];
  [self changeTrackTitle:kDefaultTitle];
  [self changeTrackArtist:kDefaultArtist];
  albumArt.image = self.albumArtDefaultImage;
}

- (void)setFailedState:(NSError *)error {
  // If we loose network reachability both callbacks will get call, so we
  // step aside if a network lose has happened.
  if ([[RRQReachability sharedReachability] remoteHostStatus] == NotReachable) {
    // The reachability callback will show its own AlertView.
    return;
  }
  
  controlButton.hidden = NO;
  loadingImage.hidden = YES;
  if (loadingImage.isAnimating)
    [loadingImage stopAnimating];
  [controlButton setImage:playImage forState:UIControlStateNormal];
  [controlButton setImage:playHighlightImage forState:UIControlStateHighlighted];
  [self changeTrackTitle:kDefaultTitle];
  [self changeTrackArtist:kDefaultArtist];
  albumArt.image = self.albumArtDefaultImage;
  
  NSString *message;
  if (error != nil) {
    message = [NSString stringWithFormat:@"Ha sucedido un error \"%@\".\nLo sentimos mucho.", error.localizedDescription];
  } else {
    message = @"Ha sucedido un error.\nLo sentimos mucho.";
  }
  
  UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"Problemas"
                                                      message:message
                                                     delegate:nil
                                            cancelButtonTitle:nil
                                            otherButtonTitles:@"Aceptar", nil];
  [alertView show];
  [alertView release];
}

- (void)setLoadingState {
  controlButton.hidden = YES;
  loadingImage.hidden = NO;
  if (!loadingImage.isAnimating)
    [loadingImage startAnimating];
}

- (void)playRadio {
  if ([[RRQReachability sharedReachability] remoteHostStatus] == NotReachable) {
    [self showNetworkProblemsAlert];
    return;
  }
  
  if (isPlaying) {
    return;
  }
  
  // FIX: trying to play?
  [NSThread detachNewThreadSelector:@selector(privatePlayRadio)
                           toTarget:self
                         withObject:nil];
}

- (void)privatePlayRadio {
  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
  
  [self performSelector:@selector(setLoadingState)
               onThread:[NSThread mainThread]
             withObject:nil
          waitUntilDone:NO];
  
  player = [[RRQShoutcastAudioPlayer alloc] initWithString:kFIFMRadioURL audioTypeHint:kAudioFileMP3Type];
  // player.connectionFilter = [[FIShoutcastMetadataFilter alloc] init];
  
  player.delegate = self;
  [player addObserver:self forKeyPath:@"isPlaying" options:0 context:nil];
  [player addObserver:self forKeyPath:@"failed" options:0 context:nil];
  [player start];
  
  isPlaying = YES;
  
  [pool release];
}

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context {
  if (object == player) {
    if ([keyPath isEqual:@"isPlaying"]) {
      NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
      
      if ([player isPlaying]) { // Started playing
        [self performSelector:@selector(setPlayState)
                     onThread:[NSThread mainThread]
                   withObject:nil
                waitUntilDone:NO];
      } else {
        [player removeObserver:self forKeyPath:@"isPlaying"];
        [player removeObserver:self forKeyPath:@"failed"];
        [player release];
        player = nil;
        
        isPlaying = NO;
        
        [self performSelector:@selector(setStopState)
                     onThread:[NSThread mainThread]
                   withObject:nil
                waitUntilDone:NO];
      }
      
      [pool release];
      return;
    } else if ([keyPath isEqual:@"failed"]) {
      NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
      
      if ([player failed]) { // Have failed
        RNLog(@"failed!");
        [self performSelector:@selector(setFailedState:)
                     onThread:[NSThread mainThread]
                   withObject:player.error
                waitUntilDone:NO];
      } else { // Have un-failed. Can't happen
        RNLog(@"un-failed?");
      }
      
      [pool release];
      return;
    }
  }
  
  [super observeValueForKeyPath:keyPath
                       ofObject:object
                         change:change
                        context:context];
}

- (UILabel *)changeLabel:(UILabel *)label withString:(NSString *)newString orElse:(NSString *)defaultString {
  UILabel *newLabel = [[[UILabel alloc] initWithFrame:label.frame] autorelease];
  newLabel.font = label.font;
  newLabel.textColor = label.textColor;
  newLabel.textAlignment = label.textAlignment;
  newLabel.backgroundColor = label.backgroundColor;
  newLabel.opaque = label.opaque;
  
  NSString *cleanString = [newString stringByTrimmingCharactersInSet:
                           [NSCharacterSet whitespaceAndNewlineCharacterSet]];
  if (newString && [cleanString length] > 0) {
    newLabel.text = cleanString;
  } else {
    newLabel.text = defaultString;
  }
  
  newLabel.alpha = 0.0;
  UIView *container = label.superview;
  [container addSubview:newLabel];

  CGContextRef context = UIGraphicsGetCurrentContext();
	[UIView beginAnimations:nil context:context];
  [UIView setAnimationCurve:UIViewAnimationCurveEaseInOut];
	[UIView setAnimationDuration:1.0];
  
  newLabel.alpha = 1.0;
  label.alpha = 0.0;
	
	[UIView commitAnimations];

  [label removeFromSuperview];
  
  return newLabel;
}

- (void)changeTrackTitle:(NSString  *)newTitle {
  titleLabel = [self changeLabel:titleLabel withString:newTitle orElse:kDefaultTitle];
}

- (void)changeTrackArtist:(NSString  *)newArtist {
  artistLabel = [self changeLabel:artistLabel withString:newArtist orElse:kDefaultArtist];
}

- (void)changeAlbumArt:(NSArray *)titleParts {
  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
  
  NSString *title = [titleParts objectAtIndex:[titleParts count]-1];
  NSString *artist = [titleParts objectAtIndex:0];
  NSURL *imageURL = [dataProvider imageForTitle:title andArtist:artist];
  
  if (!imageURL) {
    RNLog(@"image not found, using default image");
    albumArt.image = albumArtDefaultImage;
  } else {
    RNLog(@"loading image %@", imageURL);
    [albumArt loadImageFromURL:imageURL];
  }
  
  [pool release];
}

#pragma mark UIViewController methods

- (void)viewDidLoad {
  // Load some interface images
  bottomBar.backgroundColor =
    [UIColor colorWithPatternImage:[UIImage imageNamed:@"bottom-bar.png"]];
  
  self.playImage = [UIImage imageNamed:@"play.png"];
  self.playHighlightImage = [UIImage imageNamed:@"play-hl.png"];
  self.pauseImage = [UIImage imageNamed:@"pause.png"];
  self.pauseHighlightImage = [UIImage imageNamed:@"pause-hl.png"];
  
  self.albumArtDefaultImage = [UIImage imageNamed:@"default-album-cover.png"];
  albumArt.image = self.albumArtDefaultImage;
  
  // Load the loading animation files
  NSMutableArray *loadingFiles = [[NSMutableArray alloc] init];
  for (int index = 0; index < 4; index++) {
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    NSString *fileName = [NSString stringWithFormat:@"loading_%d.png", index];
    UIImage *frame = [UIImage imageNamed:fileName];
    [loadingFiles addObject:frame];
    [pool release];
  }
  loadingImage.animationImages = loadingFiles;
  loadingImage.animationDuration = 1.2f;
  [loadingFiles release];
  
  // Set up the volume slider
  RRQVolumeView *volumeView =
    [[[RRQVolumeView alloc] initWithFrame:volumeViewHolder.bounds] autorelease];
  [volumeViewHolder addSubview:volumeView];
  [volumeView finalSetup];
    
  // Setup the data provider
  NSString *lastFMConfigPath = [[NSBundle mainBundle] pathForResource:@"lastfm"
                                                               ofType:@"plist"];
  NSData *lastFMConfigData;
  NSString *error;
  NSPropertyListFormat format;
  NSDictionary *lastFMConfig;
  
  lastFMConfigData = [NSData dataWithContentsOfFile:lastFMConfigPath];
  lastFMConfig = (NSDictionary *) [NSPropertyListSerialization
                                   propertyListFromData:lastFMConfigData
                                       mutabilityOption:NSPropertyListImmutable
                                                 format:&format
                                       errorDescription:&error];
  if (lastFMConfig) {
    NSString *lastFMApiKey = [lastFMConfig objectForKey:@"api_key"];
    dataProvider = [[FILastFMDataProvider alloc] initWithApiKey:lastFMApiKey];
  } else {
    RNLog(@"Error loading last.fm configuration");
    // TODO: dataprovider is nil all the time?
  }
  
  [super viewDidLoad];
}

- (void)viewDidAppear:(BOOL)animated {
  // Needed to start receiving reachability status notifications
  [[RRQReachability sharedReachability] remoteHostStatus];
    
  [super viewDidAppear:animated];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning]; // Releases the view if it doesn't have a superview
    // Release anything that's not essential, such as cached data
}



#pragma mark ShoutcastPlayerDelegate methods

- (void)player:(RRQShoutcastAudioPlayer *)player
  updatedMetadata:(NSDictionary *)metadataDictionary {
  NSString *value;
  if (isPlaying && (value = [metadataDictionary objectForKey:@"StreamTitle"])) {
    RNLog(@"StreamTitle found! %@", value);
    NSArray *titleParts = [value componentsSeparatedByString:@"-"];
    [self performSelector:@selector(changeTrackTitle:)
                 onThread:[NSThread mainThread]
               withObject:[titleParts objectAtIndex:[titleParts count]-1]
            waitUntilDone:NO];
    [self performSelector:@selector(changeTrackArtist:)
                 onThread:[NSThread mainThread]
               withObject:[titleParts objectAtIndex:0]
            waitUntilDone:NO];
    [NSThread detachNewThreadSelector:@selector(changeAlbumArt:)
                             toTarget:self withObject:titleParts];
  }
}


#pragma mark Dealloc

- (void)dealloc {
  self.playImage = nil;
  self.playHighlightImage = nil;
  self.pauseImage = nil;
  self.pauseHighlightImage = nil;
  self.albumArtDefaultImage = nil;
  
  if (dataProvider) [dataProvider release];
  
  [super dealloc];
}


@end
