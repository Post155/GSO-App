# Map package assets

Copy `GSO.app/Model/SchoolGrid.bin` from the original Swift repository to `legacy_v1/SchoolGrid.bin` to enable the binary-reader adapter. Do not publish it as a production map until the 1.OG grid has been regenerated from the supplied 1.OG drawing and on-site route tests pass.

The app preview deliberately uses the two supplied floor-plan images but does not draw room markers because accurate coordinate-to-image transforms and door/entrance nodes have not yet been validated.
