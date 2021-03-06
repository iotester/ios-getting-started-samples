/*
 * Copyright (c) 2016 Adobe Systems Incorporated. All rights reserved.
 *
 * Permission is hereby granted, free of charge, to any person obtaining a
 * copy of this software and associated documentation files (the "Software"),
 * to deal in the Software without restriction, including without limitation
 * the rights to use, copy, modify, merge, publish, distribute, sublicense,
 * and/or sell copies of the Software, and to permit persons to whom the
 * Software is furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 * FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
 * DEALINGS IN THE SOFTWARE.
 */

#import <AdobeCreativeSDKCore/AdobeCreativeSDKCore.h>
#import <AdobeCreativeSDKAssetModel/AdobeCreativeSDKAssetModel.h>
#import <AdobeCreativeSDKAssetUX/AdobeCreativeSDKAssetUX.h>

#import "ViewController.h"

#define userSpecificPathKey @"userSpecificPathKey"

#warning Please update the client ID and secret values to match the ones provided by creativesdk.com
static NSString * const kCreativeSDKClientId = @"Change me";
static NSString * const kCreativeSDKClientSecret = @"Change me";
static NSString * const kCreativeSDKRedirectURLString = @"Change me";

@interface ViewController () <AdobeUXAssetUploaderViewControllerDelegate, AdobeLibraryDelegate>

@property (strong, nonatomic) NSString *rootLibDir;

@end

@implementation ViewController

@synthesize autoSyncDownloadedAssets;
@synthesize syncOnCommit;
@synthesize libraryQueue;
@synthesize assetDownloadLibraryFilter;

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.

    // Set the client ID and secret values so the CSDK can identify the calling app. The three
    // specified scopes are required at a minimum.
    [[AdobeUXAuthManager sharedManager] setAuthenticationParametersWithClientID:kCreativeSDKClientId
                                                                   clientSecret:kCreativeSDKClientSecret
                                                            additionalScopeList:@[AdobeAuthManagerUserProfileScope,
                                                                                  AdobeAuthManagerEmailScope,
                                                                                  AdobeAuthManagerAddressScope]];
    
    // Also set the redirect URL, which is required by the CSDK authentication mechanism.
    [AdobeUXAuthManager sharedManager].redirectURL = [NSURL URLWithString:kCreativeSDKRedirectURLString];
    
    // If you do provide a logout option, listen for the observer. If anytime the user uploaded to libraries,
    // your app will have configured AdobeLibraryManager and hence synced the user libraries.
    // You can clear them from your local device when user logs out.
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(authDidLogout:)
                                                 name:AdobeAuthManagerLoggedOutNotification
                                               object:nil];
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:AdobeAuthManagerLoggedOutNotification
                                                  object:nil];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Asset Uploader Handler

- (IBAction)showAssetUploader
{
    AdobeUXAssetUploaderConfiguration *browserConfig = [AdobeUXAssetUploaderConfiguration new];
    
    // For the purpose of this demo we randomly pick the number of images we want to upload.
    NSUInteger numberOfAssets = [self randomValueBetween:2 and:8];
    NSMutableArray *assetsToUpload = [NSMutableArray new];
    
    for (NSUInteger i = 1; i <= numberOfAssets; i++)
    {
        AdobeUXAssetBrowserConfigurationProxyAsset *assetToUpload = [AdobeUXAssetBrowserConfigurationProxyAsset new];
        
        // Assign a unique ID
        assetToUpload.assetId = [NSString stringWithFormat:@"Image%lu", (unsigned long)i];
        
        // Image name could be anything, in this case it is Image1, Image2, etc
        assetToUpload.name = [NSString stringWithFormat:@"Image (%lu)", (unsigned long)i];
        
        // Provide the thumbnails to image that is being uploaded. (Randomly pick a image to upload for this demo from the images folder within project.)
        NSString *thumbnailName = [NSString stringWithFormat:@"Image%d", [self randomValueBetween:1 and:8]];
        assetToUpload.thumbnail = [UIImage imageWithContentsOfFile:[[NSBundle mainBundle] pathForResource:thumbnailName ofType:@"png"]];
        
        [assetsToUpload addObject:assetToUpload];
    }
    
    browserConfig.assetsToUpload = assetsToUpload;
    AdobeUXAssetUploaderViewController *vc = [AdobeUXAssetUploaderViewController assetUploaderViewControllerWithConfiguration:browserConfig
                                                                                                                     delegate:self];
    
    [self presentViewController:vc animated:YES completion:nil];
}

#pragma mark - AdobeUXAssetUploaderViewControllerDelegate

- (void)assetUploaderViewController:(AdobeUXAssetUploaderViewController *)assetUploader didSelectDestination:(AdobeSelection *)destination assetsToUpload:(NSDictionary<NSString *, NSString *> *)assetsToUpload
{
    [self dismissViewControllerAnimated:YES completion:nil];
    
    NSLog(@"Asset Uploader success! Destination folder: %@\nImages to upload: %@", destination.selectedItem, assetsToUpload);
    
    NSMutableString *message = [NSMutableString new];
    
    if (IsAdobeAssetFolder(destination.selectedItem))
    {
        AdobeAssetFolder *selectedFolder = destination.selectedItem;
        
        [message appendFormat:@"Folder - %@", selectedFolder.href];
    }
    else if ([destination.selectedItem isKindOfClass:[AdobeLibraryComposite class]])
    {
        AdobeLibraryComposite *selectedLibrary = destination.selectedItem;
        
        // Start the AdobeLibraryManager so that assets can be added to libraries & synced.
        [self setupAdobeLibraryManager:AdobeLibraryDownloadPolicyTypeManifestOnly];
        
        [message appendFormat:@"Library - %@", selectedLibrary.name];
    }
    else if (IsAdobePhotoCollection(destination.selectedItem))
    {
        AdobePhotoCollection *selectedPhotoCollection = destination.selectedItem;
        
        [message appendFormat:@"Photo Collection - %@", selectedPhotoCollection.name];
    }
    else if (IsAdobePhotoCatalog(destination.selectedItem))
    {
        AdobePhotoCatalog *selectedPhotoCatalog = destination.selectedItem;
        [message appendFormat:@"Photo Catalog - %@", selectedPhotoCatalog.name];
    }
    
    [message appendString:@"\n\nImage Names:\n"];
    
    // Perform the upload.
    for (NSString *assetId in assetsToUpload.allKeys)
    {
        [message appendFormat:@"%@\n", assetsToUpload[assetId]];
        
        NSURL *assetURL = [NSURL URLWithString:[[NSBundle mainBundle] pathForResource:assetId
                                                                               ofType:@"png"]];
        
        if (IsAdobeAssetFolder(destination.selectedItem))
        {
             AdobeAssetFolder *selectedFolder = destination.selectedItem;
            
            // Upload assets to selected folder.
            [AdobeAssetFile create:assetId
                            folder:selectedFolder
                          dataPath:assetURL
                       contentType:kAdobeMimeTypePNG
                     progressBlock:nil
                      successBlock:^(AdobeAssetFile *file)
             {
                 NSLog(@"Upload success: %@", assetId);
             }
                 cancellationBlock:nil
                        errorBlock:^(NSError *error)
             {
                 NSLog(@"Upload failed: %@", error);
             }];
        }
        else if ([destination.selectedItem isKindOfClass:[AdobeLibraryComposite class]])
        {
            AdobeLibraryComposite *composite = destination.selectedItem;
            NSError *error = nil;
            
            // Add assets to selected library and perform sync.
            [AdobeDesignLibraryUtils addImage:assetURL
                                         name:assetId
                                      library:composite
                                        error:&error];
            
            if (error == nil)
            {
                NSLog(@"Added to library: %@", assetId);
            }
            else
            {
                NSLog(@"Add to library failed: %@", error);
            }
        }
        else if (IsAdobePhotoCollection(destination.selectedItem))
        {
            AdobePhotoCollection *selectedPhotoCollection = destination.selectedItem;
            
            // Upload assets to selected photo collection.
            [AdobePhotoAsset create:assetId
                         collection:selectedPhotoCollection
                           dataPath:assetURL
                        contentType:kAdobeMimeTypePNG
                      progressBlock:nil
                       successBlock:^(AdobePhotoAsset *asset)
             {
                 NSLog(@"Upload success: %@", assetId);
             }
                  cancellationBlock:nil
                         errorBlock:^(NSError *error)
             {
                 NSLog(@"Upload failed: %@", error);
             }];
        }
        else if (IsAdobePhotoCatalog(destination.selectedItem))
        {
            AdobePhotoCatalog *selectedPhotoCatalog = destination.selectedItem;
            
            // Upload assets to selected photo catalog.
            [AdobePhotoAsset create:assetId
                            catalog:selectedPhotoCatalog
                           dataPath:assetURL
                        contentType:kAdobeMimeTypePNG
                      progressBlock:nil
                       successBlock:^(AdobePhotoAsset *asset)
             {
                 NSLog(@"Upload success: %@", assetId);
             }
                  cancellationBlock:nil
                         errorBlock:^(NSError *error)
             {
                 NSLog(@"Upload failed: %@", error);
             }];
        }
    }
    
    // Uploading to libraries, then perform sync.
    if ([destination.selectedItem isKindOfClass:[AdobeLibraryComposite class]])
    {
        // Perform sync so that the added assets are uploaded & a delegate callback is received on
        // sync complete.
        AdobeLibraryManager *libMgr = [AdobeLibraryManager sharedInstance];
        [libMgr sync];
    }
    
    [message appendString:@"\n Your images are being uploaded asynchronously to destination. "
        "Please refer the console log for upload success or error for each image."];
    
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"Uploading Images"
                                                                             message:message
                                                                      preferredStyle:UIAlertControllerStyleAlert];
    
    UIAlertAction *okAction = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil];
    [alertController addAction:okAction];
    
    [self presentViewController:alertController animated:YES completion:nil];
}

- (void)assetUploaderViewController:(AdobeUXAssetUploaderViewController *)assetUploader didEncounterError:(NSError *)error
{
    [self dismissViewControllerAnimated:YES completion:nil];
    
    NSLog(@"Asset Uploader failed with error: %@", error);
    
    NSString *message = [NSString stringWithFormat:@"Error: %@", error];
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"Upload Error"
                                                                             message:message
                                                                      preferredStyle:UIAlertControllerStyleAlert];
    
    UIAlertAction *okAction = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil];
    [alertController addAction:okAction];
    
    [self presentViewController:alertController animated:YES completion:nil];
}

- (void)assetUploaderViewControllerDidClose:(AdobeUXAssetUploaderViewController *)assetUploader
{
    [self dismissViewControllerAnimated:YES completion:nil];
    
    NSLog(@"Asset Uploader was dismissed without selecting a destination folder.");
}

#pragma mark - AdobeLibraryDelegate

- (void)syncFinished
{
    // AdobeLibraryManager completed sync, hence deregister as delegate so that AdobeLibraryManager shuts down.
    [[AdobeLibraryManager sharedInstance] deregisterDelegate:self];
}

#pragma mark - Notification handlers

- (void)authDidLogout:(NSNotification *)notification
{
    if (self.rootLibDir.length > 0)
    {
        [AdobeLibraryManager removeLocalLibraryFilesInRootFolder:self.rootLibDir withError:nil];
        
        // Clean up the root folder.
        NSFileManager *fm = [NSFileManager defaultManager];
        [fm removeItemAtPath:[[self.rootLibDir stringByDeletingLastPathComponent] stringByDeletingLastPathComponent] error:nil];
        self.rootLibDir = nil;
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:userSpecificPathKey];
    }
}

#pragma mark - Private methods

- (NSString *)UUIDForUserSpecificPath
{
    // If we have a UUID then use it.
    NSString *userSpecificID = [[NSUserDefaults standardUserDefaults] objectForKey:userSpecificPathKey];
    
    if (userSpecificID.length > 0)
    {
        return userSpecificID;
    }
    
    // Generate a new UUID
    userSpecificID = [NSUUID UUID].UUIDString;
    
    [[NSUserDefaults standardUserDefaults] setObject:userSpecificID forKey:userSpecificPathKey];
    
    return userSpecificID;
}

- (void)setupAdobeLibraryManager:(AdobeLibraryDownloadPolicyType)downloadPolicy
{
    // Below is the setup for configure & start AdobeLibraryManager.
    // For more info regarding libraries please refer: https://creativesdk.adobe.com/docs/ios/#/articles/libraries/index.html.
    AdobeLibraryDelegateStartupOptions *startupOptions = [AdobeLibraryDelegateStartupOptions new];

    startupOptions.autoDownloadPolicy = downloadPolicy;
    startupOptions.autoDownloadContentTypes = @[kAdobeMimeTypeJPEG,
                                                kAdobeMimeTypePNG];
    startupOptions.elementTypesFilter = @[AdobeDesignLibraryColorElementType,
                                          AdobeDesignLibraryColorThemeElementType,
                                          AdobeDesignLibraryCharacterStyleElementType,
                                          AdobeDesignLibraryBrushElementType,
                                          AdobeDesignLibraryImageElementType,
                                          AdobeDesignLibraryLayerStyleElementType];
    syncOnCommit = YES;
    libraryQueue = [NSOperationQueue mainQueue];
    autoSyncDownloadedAssets = NO;
    
    AdobeLibraryManager *libMgr = [AdobeLibraryManager sharedInstance];
    libMgr.syncAllowedByNetworkStatusMask = AdobeNetworkReachableViaWiFi | AdobeNetworkReachableViaWWAN;
    
    NSString *rootLibDir = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES)[0];
    rootLibDir = [rootLibDir stringByAppendingPathComponent:@"libraries"];
    
    // User specific path to sync libraries from cloud.
    self.rootLibDir = [rootLibDir stringByAppendingPathComponent:[self UUIDForUserSpecificPath]];
    NSError *libErr = nil;
    
    // Start the AdobeLibraryManager.
    [libMgr startWithFolder:self.rootLibDir andError:&libErr];
    
    // Register as delegate to get callbacks.
    [libMgr registerDelegate:self options:startupOptions];
}

- (u_int32_t)randomValueBetween:(u_int32_t)min and:(u_int32_t)max
{
    return (min + arc4random_uniform(max - min + 1));
}

@end
