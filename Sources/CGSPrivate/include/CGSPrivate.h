#ifndef CGSPrivate_h
#define CGSPrivate_h

#include <CoreGraphics/CoreGraphics.h>
#include <ApplicationServices/ApplicationServices.h>

typedef int CGSConnectionID;
typedef uint64_t CGSSpaceID;

// Space type constants for CGSCopySpaces
typedef enum {
    kCGSSpaceIncludesCurrent = 5,
    kCGSSpaceIncludesOthers = 6,
    kCGSSpaceIncludesUser = 7
} CGSSpaceSelector;

extern CGSConnectionID CGSMainConnectionID(void);
extern CGSSpaceID CGSGetActiveSpace(CGSConnectionID cid);
extern CFArrayRef CGSCopySpaces(CGSConnectionID cid, CGSSpaceSelector selector);

// Space type: 0 = regular desktop, 4 = fullscreen
extern int CGSSpaceGetType(CGSConnectionID cid, CGSSpaceID space);

// Returns spaces per display in Mission Control order
extern CFArrayRef CGSCopyManagedDisplaySpaces(CGSConnectionID cid);

// Move windows between spaces
extern void CGSAddWindowsToSpaces(CGSConnectionID cid, CFArrayRef windowIDs, CFArrayRef spaceIDs);
extern void CGSRemoveWindowsFromSpaces(CGSConnectionID cid, CFArrayRef windowIDs, CFArrayRef spaceIDs);

// Move windows atomically to a managed space
extern void CGSMoveWindowsToManagedSpace(CGSConnectionID cid, CFArrayRef windowIDs, CGSSpaceID space);

// Switch the active space on a display
extern void CGSManagedDisplaySetCurrentSpace(CGSConnectionID cid, CFStringRef displayUUID, CGSSpaceID space);

// Get the display UUID that contains a given space
extern CFStringRef CGSCopyManagedDisplayForSpace(CGSConnectionID cid, CGSSpaceID space);

// Get window ID from AXUIElement
extern AXError _AXUIElementGetWindow(AXUIElementRef element, uint32_t *windowID);

#endif /* CGSPrivate_h */
