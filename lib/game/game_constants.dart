const double bubbleRadius = 18;
const double bubbleSpacing = -0.5;
const double bubbleDiameter = (bubbleRadius * 2) + bubbleSpacing;
const double rowHeight = bubbleDiameter * 0.866;

// Push grid below the HUD overlay (~150px on most Android phones)
const double gridTopPadding = 165;

// Shoot cooldown in seconds — prevents rapid-fire snapping glitches
const double shootCooldown = 0.1;

// Grid movement settings
const double autoShiftInterval = 4.5; // Faster drops (was 6.0)
const double shiftAnimDuration = 0.25; // Smoother but faster movement
const double popAnimDuration = 0.1;
