//
//  ALAudioAttachmentViewController.m
//  Applozic
//
//  Created by devashish on 19/02/2016.
//  Copyright © 2016 applozic Inc. All rights reserved.
//

#import "ALAudioAttachmentViewController.h"

@interface ALAudioAttachmentViewController ()
{
    AVAudioRecorder *recorder;
    AVAudioPlayer *player;
}
@end

@implementation ALAudioAttachmentViewController

-(void)viewDidLoad
{
    [super viewDidLoad];
    
    [self.pauseButton setEnabled:NO];
    [self.stopButton setEnabled:NO];
    [self.playButton setEnabled:NO];
    [self.sendButton setEnabled:NO];
    
    // Set the audio file
    NSString *fileName = [NSString stringWithFormat:@"AUD-%f.m4a",[[NSDate date] timeIntervalSince1970] * 1000];
    NSArray *pathComponents = [NSArray arrayWithObjects:
                               [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject],
                               fileName, nil];
    
    NSURL *outputFileURL = [NSURL fileURLWithPathComponents:pathComponents];
    
    // Setup audio session
    AVAudioSession *session = [AVAudioSession sharedInstance];
    [session setCategory:AVAudioSessionCategoryPlayAndRecord withOptions:AVAudioSessionCategoryOptionDefaultToSpeaker error:nil];
    
    NSMutableDictionary *recordSetting = [[NSMutableDictionary alloc] init];
    
    [recordSetting setValue:[NSNumber numberWithInt:kAudioFormatMPEG4AAC] forKey:AVFormatIDKey];
    [recordSetting setValue:[NSNumber numberWithFloat:44100.0] forKey:AVSampleRateKey];
    [recordSetting setValue:[NSNumber numberWithInt: 2] forKey:AVNumberOfChannelsKey];
    
    recorder = [[AVAudioRecorder alloc] initWithURL:outputFileURL settings:recordSetting error:nil];
    recorder.delegate = self;
    recorder.meteringEnabled = YES;
    [recorder prepareToRecord];
    
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (IBAction)pauseButtonAction:(id)sender
{
    [player pause];
}

-(IBAction)playButtonAction:(id)sender
{
    if (!recorder.recording)
    {
        player = [[AVAudioPlayer alloc] initWithContentsOfURL:recorder.url error:nil];
        [player setDelegate:self];
        [player play];
    }
}

-(IBAction)stopButtonAction:(id)sender
{
    [recorder stop];
    [self.timer invalidate];
    AVAudioSession *audioSession = [AVAudioSession sharedInstance];
    [audioSession setActive:NO error:nil];
    [self.sendButton setEnabled:YES];
}

-(IBAction)sendButtonAction:(id)sender
{
    self.outputFilePath = [recorder.url path];
    [self.audioAttchmentDelegate audioAttachment: self.outputFilePath];
    [self.navigationController popViewControllerAnimated:YES];
}

- (IBAction)recordAction:(id)sender
{
    if (player.playing)
    {
        [player stop];
    }
    
    if (!recorder.recording)
    {
        AVAudioSession *session = [AVAudioSession sharedInstance];
        [session setActive:YES error:nil];
        [self.recordButton setTitle:@"PAUSE RECORD" forState:UIControlStateNormal];
        
        // Start recording
        [recorder record];
        self.timer = [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(recordSessionTimer) userInfo:nil repeats:YES];;
        
    }
    else
    {
        // Pause recording
        [recorder pause];
        [self.recordButton setTitle:@"RECORD" forState:UIControlStateNormal];
    }
    
    [self.stopButton setEnabled:YES];
    [self.playButton setEnabled:NO];
    [self.pauseButton setEnabled:NO];
}

-(IBAction)cancelAction:(id)sender
{
    [self.navigationController popViewControllerAnimated:YES];
}

-(void)recordSessionTimer
{
    float minutes = floor(recorder.currentTime / 60);
    float seconds = recorder.currentTime - (minutes * 60);
    
    NSString *time = [NSString stringWithFormat:@"%0.0f : %0.0f", minutes, seconds];
    [self.mediaProgressLabel setText: time];
}

//=====================================================
#pragma AUDIO DELEGATE
//=====================================================

-(void)audioRecorderDidFinishRecording:(AVAudioRecorder *)recorder successfully:(BOOL)flag
{
    [self.recordButton setTitle:@"RECORD" forState:UIControlStateNormal];
    [self.stopButton setEnabled:NO];
    [self.playButton setEnabled:YES];
    [self.pauseButton setEnabled:YES];
}

-(void)audioPlayerDidFinishPlaying:(AVAudioPlayer *)player successfully:(BOOL)flag
{
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle: @"DONE"
                                                    message: @"FINISH PLAYING !!!"
                                                   delegate: nil
                                          cancelButtonTitle:@"OK"
                                          otherButtonTitles:nil];
    [alert show];
}

@end
