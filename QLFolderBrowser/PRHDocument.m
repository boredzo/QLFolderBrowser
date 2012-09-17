//
//  PRHDocument.m
//  QLFolderBrowser
//
//  Created by Peter Hosey on 2012-09-14.
//  Copyright (c) 2012 Peter Hosey. All rights reserved.
//

#import "PRHDocument.h"

#import <Quartz/Quartz.h>
#import <objc/runtime.h>

@interface PRHDocument () <NSTableViewDataSource, NSTableViewDelegate, QLPreviewPanelDataSource, QLPreviewPanelDelegate>

@property(copy) NSArray *itemURLs;
@property NSInteger currentSelectionIndex;

@property (weak) IBOutlet NSTableView *tableView;

- (IBAction)showQuickLook:(id)sender;

@end

@implementation PRHDocument
@synthesize tableView = _tableView;

- (id)init {
	self = [super init];
	if (self) {
		self.currentSelectionIndex = -1;
	}
	return self;
}

- (NSString *)windowNibName {
	return @"PRHDocument";
}

- (void)windowControllerDidLoadNib:(NSWindowController *)aController {
	[super windowControllerDidLoadNib:aController];
}

+ (BOOL)autosavesInPlace {
    return YES;
}

- (BOOL)readFromURL:(NSURL *)url ofType:(NSString *)typeName error:(NSError *__autoreleasing *)outError {
	self.itemURLs = [[NSFileManager defaultManager] contentsOfDirectoryAtURL:url
												  includingPropertiesForKeys:@[ NSURLNameKey, NSURLEffectiveIconKey ]
																	 options:NSDirectoryEnumerationSkipsSubdirectoryDescendants
 | NSDirectoryEnumerationSkipsPackageDescendants | NSDirectoryEnumerationSkipsHiddenFiles
																	   error:outError];
	return YES;
}

- (NSInteger) numberOfRowsInTableView:(NSTableView *)tableView {
	return self.itemURLs.count;
}

- (id) attemptToGetValueFromURL:(NSURL *)itemURL forKey:(NSString *)key {
	id value;
	NSError *error;
	if (key)
		[itemURL getResourceValue:&value forKey:key error:&error];
	if (error && !value)
		[[self windowForSheet] presentError:error];

	return value;
}

- (NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
	NSTableCellView *cellView = [tableView makeViewWithIdentifier:@"file" owner:self];
	NSURL *itemURL = self.itemURLs[row];
	cellView.objectValue = itemURL;
	cellView.imageView.image = [self attemptToGetValueFromURL:itemURL forKey:NSURLEffectiveIconKey];
	cellView.textField.stringValue = [self attemptToGetValueFromURL:itemURL forKey:NSURLNameKey];

	NSDictionary *thumbnailOptions = @{
		//Causes a crash on 10.8.0.
//		(__bridge NSString *)kQLThumbnailOptionIconModeKey: @YES,
		(__bridge NSString *)kQLThumbnailOptionScaleFactorKey : @([cellView.imageView.window userSpaceScaleFactor])
	};
	NSSize thumbnailSize = cellView.imageView.frame.size;
	QLThumbnailRef thumbnail = QLThumbnailCreate(kCFAllocatorDefault, (__bridge CFURLRef)itemURL, thumbnailSize, (__bridge CFDictionaryRef)thumbnailOptions);
	QLThumbnailDispatchAsync(thumbnail, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, /*flags*/ 0), ^{
		CGImageRef thumbnailImage = QLThumbnailCopyImage(thumbnail);
		if (thumbnailImage) {
			dispatch_async(dispatch_get_main_queue(), ^{
				cellView.imageView.image = [[NSImage alloc] initWithCGImage:thumbnailImage size:thumbnailSize];

				CGImageRelease(thumbnailImage);
			});
		}

		CFRelease(thumbnail);
	});

	return cellView;
}

- (void) tableViewSelectionDidChange:(NSNotification *)notification {
	NSTableView *tableView = notification.object;
	NSIndexSet *indexes = tableView.selectedRowIndexes;
	QLPreviewPanel *previewPanel = [QLPreviewPanel sharedPreviewPanel];
	if ([indexes count] >= 1)
		self.currentSelectionIndex = indexes.firstIndex;
	else
		self.currentSelectionIndex = -1;
	if (previewPanel.dataSource == self)
		previewPanel.currentPreviewItemIndex = self.currentSelectionIndex;
}

- (BOOL) acceptsPreviewPanelControl:(QLPreviewPanel *)panel {
	return YES;
}
- (void) beginPreviewPanelControl:(QLPreviewPanel *)panel {
	panel.dataSource = self;
	panel.delegate = self;
	panel.currentPreviewItemIndex = self.currentSelectionIndex;
}
- (void) endPreviewPanelControl:(QLPreviewPanel *)panel {
	panel.dataSource = nil;
	panel.delegate = nil;
}

- (NSInteger) numberOfPreviewItemsInPreviewPanel:(QLPreviewPanel *)panel {
	return self.itemURLs.count;
}

- (id <QLPreviewItem>) previewPanel:(QLPreviewPanel *)panel previewItemAtIndex:(NSInteger)idx {
	//The preview panel may have just changed its selected item on its own (e.g., with the left/right buttons), so update our table view's selection to match.
	NSInteger indexToSelect = panel.currentPreviewItemIndex;
	NSIndexSet *indexes = (indexToSelect >= 0) ? [NSIndexSet indexSetWithIndex:indexToSelect] : [NSIndexSet indexSet];
	[self.tableView selectRowIndexes:indexes byExtendingSelection:NO];

	return self.itemURLs[idx];
}

- (NSRect)previewPanel:(QLPreviewPanel *)panel sourceFrameOnScreenForPreviewItem:(id <QLPreviewItem>)item {
	NSURL *URL = (NSURL *)item;
	NSUInteger idx = [self.itemURLs indexOfObjectIdenticalTo:URL];
	NSView *rowView = idx <= NSIntegerMax ? [self.tableView rowViewAtRow:idx makeIfNecessary:NO] : nil;
	NSRect frame = NSZeroRect;
	if (rowView) {
		frame = rowView.frame;
		frame = [self.tableView convertRect:frame toView:nil];
		frame = [self.tableView.window convertRectToScreen:frame];
	}
	return frame;
}

- (BOOL) hasAnyItems {
	return (self.itemURLs.count > 0);
}

- (IBAction)showQuickLook:(id)sender {
	QLPreviewPanel *previewPanel = [QLPreviewPanel sharedPreviewPanel];
	[previewPanel makeKeyAndOrderFront:nil];
}

@end
