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
	return cellView;
}

- (void) tableViewSelectionDidChange:(NSNotification *)notification {
	NSTableView *tableView = notification.object;
	NSIndexSet *indexes = tableView.selectedRowIndexes;
	if ([indexes count] >= 1)
		self.currentSelectionIndex = indexes.firstIndex;
	else
		self.currentSelectionIndex = 0;
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
	if (idx >= 0)
		[self.tableView selectRowIndexes:[NSIndexSet indexSetWithIndex:idx - 1] byExtendingSelection:NO];
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
	[previewPanel updateController];
	[previewPanel makeKeyAndOrderFront:nil];
}

@end
