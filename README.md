# Open source robot for liquid handing and serial multiplexing fluorescence microscopy

### Motivation

For fluorescence microscopy, a large limitation on the amount of data that can be extracted from a single sample is the number of targets that can be labeled within a sample.  Fluorophore spectral overlap limits this to around four targets in a typical setup, possibly up to ten if careful spectral demixing is done. In contrast, a single signalling pathway may contain a few hundred components.  Quantifying all of these components in a single sample would require an approach that increases the number of targets by an order of magnitude or more.  

One solution is to label targets in a sequential manner with probe signal nullification steps in between.  Target probes are introduced in sequential rounds, if possible without moving the sample off of the microscope.  After imaging, the probe signal can be removed either by stripping the probes, washing out the probe solution, or chemically or photob-leaching the label fluorophore.  With this procedure the number of targets that can be probed is expanded with the number of rounds.  With a 4 color set-up and 10 rounds, for example, there are up to 40 target channels that can be captured in such an experiment.  With clever 'barcoding' schemes, this can even scale exponentially, rather than linearly, with the number of rounds.  

To accomplish this feat, a single sample must be processed through the labelling and stripping steps repeatedly. Doing so automatically avoids many hours of exceptionally tedious work and ultimately a more precise product.  For this a form of multi-channel liquid handling is required.  To further avoid spending tens of thousands of dollars on a project that was initially unsanctioned and unfunded, a low-cost solution is certainly a benefit.

## Approach 

The *in situ* automated liquid handing needs to be able to move a selected alliquot of solution from one place off of the microscope into the sample holder.  Then this aliquot needs to be removed, the sample washed with buffer, possibly multiple times, while removing the waste solution.  Then the cycle needs to repeat.  Were this done manually, solutions would be pre-mixed in microcenterfuge tubes or a well plate.  An operator would then remove solution from each well in turn and adding to the sample holder, interspersing washing and waste removal steps.  This would likely be done with a micropippetor and disposable tips.  

Recapitulating this closely with a robotics platform is certinaly a straightforward approach.  The micropippetor could even be mounted on a gantry arm and moved between the reagent and sample locations.  Such an action is the basis of many pipetting robots.  However, the volume setting and tip ejection are motions adding extra complexity that may not be required.  If instead liquid was dosed out of a programmable pump through a reusable tip, the setting and ejection steps would be unnecessary.  The remaining motions are then to position this tip into the reagent well and then into the sample chamber with dosing via the pumps.  This forms the basis of the design here.

The liquid-handling head (actually made of 3 separate tips, detailed below) is on a carrier head.  This head has a servo motor for raising and lowering, essentially toggling between two positions.  The carrier is on a long axis that moves it from the reagent well plate location to the sample on the microscope, some distance (~450 mm) away.  The well plate is on a holder that places the base of this plate and the bottom of the sample holder in the same plane.  The well plate holder is on its own carrier on a shorter axis that allows a given row of the well plate to be selected (the first axis selects the column).  An alliquot is drawn into the liquid handling head by a pump, which then pushes to dispense this liquid at the sample.  A second tip in this head can dispense buffer from a reservoir, and a third withdraws waste.  The first pump operates in a toggle-like mode, with the second and third in a unidirectional motion only.  The grand total is then a servo, three "positioning" motors, and two "dispensing" motors. 

Turns out this list also makes a 3D printer.  The carrier axes correspond to XY, the reagent toggle pump the Z axis, and the buffer and waste pumps taking the role of a dual extruder.  The positioning precision of a hobby-level 3D printer is plenty for this application.  An open-source RAMPS controller built upon an Arduino Mega supports these 5 stepper motors, the servo, plus a bit of additional functionality, with communication over a USB serial with G code commands.  The design can capitalize on the 3D printer hobbiest community and the cheap components available for those projects.  These include the controller, motors, bearings, guide rods, and timing belts.  A bit of extruded T slot aluminum makes up the bulk of the skeleton, with the remaining parts being 3D printed on a desktop machine.

Controller code is based on Marlin, with configurating settings to work with this build.  The PC communicates with the controller through G code commands.  A MATLAB class and demo scripts simplifying these operations will be included.

## Repo contents

.\STEP Files\ - STEP files of full assembly and of the custom base plate to mount to a metric optical table.  

.\STL Files\ - All files for 3D printing.  These are ready to go into your favorite slicer software to generate 3D printer machine code.

.\Pics\ - Photos and renderings of the completed assembly.  A video of the robot motion testing in action is included. 

.\Hardware\ - Bill of Materials for all items to be purchased for this build.  This includes all fasteners and other hardware omitted in the STEP files.  A measured drawing for the base plate is included, ready to be sent to your local machine shop (or give making it yourself a shot). 

.\Code\ - Arduino controller and MATLAB PC-side codes coming soon!