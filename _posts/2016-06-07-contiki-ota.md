---
layout:     post
title:      "OTA for Contiki (CC2650 SoC)"
date:       2016-06-7
categories: programming
sidebar:    true
css: ['open-source.css']
---

<style>
.mmap-container {
  text-align: center;
  margin-top: 20px;
  margin-bottom: 20px;
}
.mmap {
  border-left: 1px solid #000;
  border-right: 1px solid #000;
  border-top: 1px solid #000;
  text-align: center;
  display: flex;
  flex-direction: column;
  justify-content: space-between;
  height: 100%;
  width: 100%;
}
.mmap > div {
  border-bottom: 1px solid #000;
}

</style>

## Implementing OTA in Contiki
<div class="alert alert-success text-center">
  Now with <b>CoAP</b>!
</div>

OTA is one of the holy grails in IoT embedded programming.  Releasing hardware out into the wild without the ability to easily address future bugs or modify behaviour without a physical recall is never a good idea, especially at scale.

However, updating the executable code inside a microcontroller is something that is intimately related to the hardware -- the flash peripheral that stores the code, the size of that flash storage, the processor instruction set, location of the interrupt table and/or bootloader code, etc.

ContikiOS itself is a highly portable system.  It compiles across a wide variety of microcontrollers and SoCs.  Therefore, one of the difficulties with developing an OTA system for Contiki is that it must be almost completely rewritten for each SoC that you want it to support.

With that in mind, the OTA system I have developed here is targeting only the [CC26xx SoC](http://www.ti.com/product/CC2650) family from Texas Instruments.  I based the general architecture off the OAD feature used in TI's own [BLE-Stack 2.1.1](http://www.ti.com/tool/ble-stack).

First, some of the bigger differences when moving from BLE-Stack to ContikiOS:

*  With BLE-Stack, it's possible to compile the actual stack code (HAL, drivers, etc.) separately from the user application code.  This allows your updates to be significantly smaller in terms of bytes, because you only replace the user application code and not the whole stack.  By contrast, Contiki always compiles one giant firmware binary that contains everything.  Separating the "stack" from the "application" would require a lot of linker script tinkering to specify which features ought to be linked where in memory, on a file-by-file basis -- of which there are hundreds!  In addition, Contiki is modified much faster by the open source community than TI's BLE-Stack.  In Contiki, changes inside the "stack" code are far more likely within the lifetime of your product, and we want to be able to send updates that can change the entire firmware binary if need be!
*  Contiki is significantly more network-protocol agnostic.  There are so many ways for new firmware data to be transported within the Contiki API!  You can use raw UDP sockets, TCP, HTTP, CoAP, etc...  In this system, I originally used HTTP.  However, I discovered that, when using CoAP and HTTP simultaneously in Contiki, I would encounter network failure.  So, I migrated my original OTA system to use CoAP instead.  It has been a worthwhile change -- it is certainly faster and simpler this way, as CoAP's binary structure lends itself well to firmware data.



## Quick Start
We will build the OTA example, and send new firmware over-the-air from our OTA server to our Sensortag.

### Acquire Source Code
We need two pieces of software:  the up-to-date Contiki fork which contains CoAP OTA code for cc26xx systems, as well as an OTA server.

```bash
# Get the OTA Image Server
git clone https://github.com/msolters/ota-server

cd ..

# Get Contiki fork w/ cc26xx OTA support
git clone https://github.com/msolters/contiki
cd contiki
git submodule update --init --recursive
```

<div class="repo-list row">
  {% for repo in site.github.public_repositories  %}
    {% if repo.name == "contiki" or repo.name == "ota-server" %}
      <a href="{{ repo.html_url }}" target="_blank">
        <div class="col-md-6 card text-center">
          <div class="thumbnail">
              <div class="card-image geopattern" data-pattern-id="{{ repo.name }}">
                  <div class="card-image-cell">
                      <h3 class="card-title">
                          {{ repo.name }}
                      </h3>
                  </div>
              </div>
              <div class="caption">
                  <div class="card-description">
                      <p class="card-text">{{ repo.description }}</p>
                  </div>
                  <div class="card-text">
                      <span data-toggle="tooltip" class="meta-info" title="{{ repo.stargazers_count }} stars">
                          <span class="octicon octicon-star"></span> {{ repo.stargazers_count }}
                      </span>
                      <span data-toggle="tooltip" class="meta-info" title="{{ repo.forks_count }} forks">
                          <span class="octicon octicon-git-branch"></span> {{ repo.forks_count }}
                      </span>
                      <span data-toggle="tooltip" class="meta-info" title="Last updated：{{ repo.updated_at }}">
                          <span class="octicon octicon-clock"></span>
                          <time datetime="{{ repo.updated_at }}" title="{{ repo.updated_at }}">{{ repo.updated_at | date: '%Y-%m-%d' }}</time>
                      </span>
                  </div>
              </div>
          </div>
        </div>
      </a>
    {% endif %}
  {% endfor %}
</div>

### Build the Contiki Example
An entire working OTA application is provided inside my Contiki fork, located at

```
contiki/examples/cc26xx-ota-bootloader
```

To build, just run `make master-hex`.

```bash
cd examples/cc26xx-ota-bootloader
make master-hex
```

The `master-hex` target produces a flashable .hex file called `/cc26xx-ota-bootloader/firmware.hex`.  `firmware.hex` is called a "master hex" because it contains in truth two binaries:

*  OTA Bootloader
*  OTA Image

<div class="alert alert-info">
  <b>OTA Bootloader</b> backups and restores OTA Images once they've been downloaded.
</div>
<div class="alert alert-info">
  An <b>OTA Image</b> is just reguar Contiki firmware, compiled with the `OTA=1` flag, and most importantly <i>bundled with metadata</i>.
</div>
<div class="alert alert-info">
  <b>Metadata</b> is a data structure used to tag firmware with version numbers and unique identifiers (among other things).  Combined, metadata and a Contiki firmware binary constitutes an <i>"OTA Image"</i>.
</div>

In this example, the OTA Image is designed to simply blink the red LED of the Sensortag.  It also triggers an OTA download attempt on boot.  This will continue until an OTA server at the provided IP is found.

When the OTA update is complete, the device will reboot with new OTA image, which is designed to blink the other LED.

You can use SmartRF Programmer 2 to flash, with the one .hex, a complete ready-to-OTA system.  The rest of this article will discuss the components in more detail.

You can watch the activity of the OTA Image's download process by connecting to the CC2650 using `115200` baud rate over UART.

<div class="alert alert-danger">
  <b>Note</b>:  The OTA system requires access to the external flash chip.  <b>You cannot simultaneously have the devpack connected to your Sensortag and have your code use the Sensortag's external flash</b>.  It's a design flaw of the Sensortag/devpack -- probably a SPI collision.  Therefore, if you are using a Sensortag for this, make sure you disconnect the Sensortag from the devpack after you flash it, and run it with its own power.  Alternatively, use the srf06 board and add your own external flash chip.  This has the advantage of allowing UART access even while downloading/reading/writing OTA images.  See below for more details about using the srf06 board.
</div>

### Start an OTA Image Server
The `ota-server.js` provided in the ota-server repo only accepts one argument, which is the path to the OTA image that you want to send over the update system.

There are two ready-to-use OTA images included with the repo, one for a Sensortag and one for an srf06 board.  Both are simply a variant of the firmware found in the `cc26xx-ota-bootloader` example.  They both have metadata declaring them version number v1.  They can be distinguished from the initial firmware because they will blink a different color LED!

To start the OTA server, just execute `ota-server.js` using the NodeJS binary and pass in the OTA Image to be served as an update:

```bash
node ota-server.js ota-image-example.bin
```

The server will run on your machine's IPv6 localhost, `::1` on port `5386`.  This is the standard port for the CoAP protocol (`coap://[::1]`).  The server should listen on any other external hostname that machine has.  (In my border router, I use `coap://[bbbb::1]`)

Once the Sensortag is able to resolve the host and port of your OTA server, it will begin downloading the new `ota-image-example.bin` OTA image via CoAP blockwise transfer.  When it is done, it will restart, and begin blinking the other LED as the new firmware is executed.

<div class="alert alert-danger">
  It seems running the CC2650 with a debugger such as the devpack attached can interfere with software reboots.  If the Sensortag seems to just turn off or freeze after download, disconnect it from the devpack and power it using external power such as a battery.
</div>

## Using the srf06 Board

![srf board with external flash chip]({{site.exturl}}/assets/images/ota-srf-board.jpg)

While developing, it's helpful to have UART access to the CC26XX module.  Unfortunately, the Sensortag is very badly equipped for this purpose.  Because the devpack is required to get convenient UART communication (via USB), and because the devpack interferes with SPI which is used by the external flash, you cannot simultaneously have UART output *and* have the external flash be recognized by your firmware.  It is more convenient to use the srf06 development board and a CC2650-EM module.

### Add External Flash Chip
First, you need to attach an external flash chip to the SRF06.  I recommend the same chip that TI uses in the Sensortag, the [W25X40CL](http://www.digikey.com/product-detail/en/winbond-electronics/W25X40CLSNIG/W25X40CLSNIG-ND/3008652?cur=USD&lang=en).

![external flash circuit]({{site.exturl}}/assets/images/eagle-ext-flash.png)

For a ready-made breakout of the above, please see [this excellent Eagle repository](https://github.com/viccarre/W25X40_BREAKOUT) by Driblet Labs EE [Victor Carreño](https://github.com/viccarre).  This circuit should be connected to the srf06 board according to the following GPIO map.

Schematic label|  DIO Pin | EM RF Pin
---|---|---
MISO | IOID_8 | 1.20
MOSI | IOID_9 | 1.18
CLK | IOID_10 | 1.16
CS | IOID_14 | 1.17
VCC (3.3 VDC) | - | -
GND (0.0 VDC) | - | -


### Software Modifications
Once you have the external flash chip physically connected to the SRF06 board, we need to modify the following files so that the bootloader knows about the new SPI configuration, and so that our OTA image firmware knows to compile for the `srf06/cc26xx` board target instead of `sensortag/cc2650`.

* `platform/srf06-cc26xx/srf06/Makefile.srf06`: Add `common` to the `CONTIKI_TARGET_DIRS` and make sure to add SPI and ext-flash drivers to `BOARD_SOURCEFILES`.

  ```bash
  CFLAGS += -DBOARD_SMARTRF06EB=1

  CONTIKI_TARGET_DIRS += srf06 common

  BOARD_SOURCEFILES += board-spi.c ext-flash.c leds-arch.c srf06-sensors.c button-sensor.c board.c

  ### Signal that we can be programmed with cc2538-bsl
  BOARD_SUPPORTS_BSL=1
  ```

* `examples/cc26xx-ota-bootloader/bootloader/ext-flash/spi-pins.h`:  We need to make sure the bootloader is using the right SPI pins!

  ```c
  #ifndef SPI_PINS_H_
  #define SPI_PINS_H_
  /**
   *    How is the ext-flash hardware connected to your board?
   *    Enter pin definitions here.
   */
  #include "ioc.h"

  #define BOARD_IOID_FLASH_CS       IOID_14
  #define BOARD_FLASH_CS            (1 << BOARD_IOID_FLASH_CS)

  /**
   *  For srf06 board:
   */
  #define BOARD_IOID_SPI_CLK_FLASH  IOID_10
  #define BOARD_IOID_SPI_MOSI       IOID_9
  #define BOARD_IOID_SPI_MISO       IOID_8

  /**
   *  For Sensortag:
   */
  /** COMMENT THESE DEFINITIONS
  #define BOARD_IOID_SPI_CLK_FLASH  IOID_17
  #define BOARD_IOID_SPI_MOSI       IOID_19
  #define BOARD_IOID_SPI_MISO       IOID_18
  */
  #endif

  ```
* `examples/cc26xx-ota-bootloader/ota-image-example/project-conf.h`:  We need to make sure our OTA image is using the right SPI pins!  Uncomment the srf06-specific definitions found in the file.


  ```c
  #undef UIP_CONF_BUFFER_SIZE
  #define UIP_CONF_BUFFER_SIZE           1280

  #undef REST_MAX_CHUNK_SIZE
  #define REST_MAX_CHUNK_SIZE            256


  /**
  *  For srf06 board we must specify SPI connections by uncommenting these
  */
  #define BOARD_IOID_FLASH_CS       IOID_14
  #define BOARD_FLASH_CS            (1 << BOARD_IOID_FLASH_CS)
  #define BOARD_IOID_SPI_CLK_FLASH  IOID_10
  #define BOARD_IOID_SPI_MOSI       IOID_9
  #define BOARD_IOID_SPI_MISO       IOID_8
  ```

* `examples/cc26xx-ota-bootloader/ota-image-example/Makefile`:  Finally, in the first few lines of the OTA image Makefile, comment out the `sensortag` board target, and *un*comment the line with the `srf06` board:

  ```bash
  #BOARD=sensortag/CC2650
  BOARD=srf06/cc26xx
  ```


## Memory Map Architecture
The CC2650's internal flash can store 128Kb.  We are going to assume, as a reasonable upper bound for our Contiki applications, 100Kb per OTA image.

If we are assuming OTA images of 100Kb, we clearly cannot store more than one copy of our firmware on the internal flash at any one point in time.  This introduces another subproblem -- what if, for any reason, the firmware image stored in the internal flash should be corrupted or unable to boot?

The answer is to implement external flash storage.  The CC2650 Sensortag board, for instance, comes equipped with an external 500Kb EEPROM chip, [accessible via SPI](https://github.com/contiki-os/contiki/blob/master/platform/srf06-cc26xx/common/ext-flash.h).  We will utilize this external flash (or "ext-flash" as per the Contiki API) storage to hold two flavors of firmware:

*  Golden Image - This is a single backup of the device firmware, as it came out of the factory.  If anything should ever go completely wrong, we can restore our device's internal firmware from this external backup copy.  This is five-star, finisher firmware.
*  OTA Downloads - We will store firmware images downloaded from the OTA server in ext-flash as well.  We will only ever write one of these versions to the *internal* flash at any given time.  But, by keeping several versions on hand, we can always iteratively fall back to previous firmware versions in the event of corrupt downloads, bad firmware releases, corrupted flash R/W, etc.

So, the overall idea behind the upgrade mechanism is as follows:

<div class="row">
  <div class="col-md-6">
    <div class="mmap-container">
      <div class="mmap">
        <div class="bg-success">
          CCFG
          <br>
          88 bytes
        </div>
        <div>
          Blank
          <br>
          &#8818; 20Kb
        </div>
        <div class="bg-danger">
          Current Firmware
          <br>
          100Kb
        </div>
        <div class="bg-success">
          Bootloader
          <br>
          8Kb
        </div>
      </div>
      <div style="text-align: center">
        <b>Internal Flash</b>
      </div>
    </div>
  </div>
  <div class="col-md-6">
    <div class="mmap-container">
      <div class="mmap">
        <div class="bg-danger">
          OTA Image 3
          <br>
          100Kb
        </div>
        <div class="bg-danger">
          OTA Image 2
          <br>
          100Kb
        </div>
        <div class="bg-danger">
          OTA Image 1
          <br>
          100Kb
        </div>
        <div class="bg-success">
          Golden Image
          <br>
          100Kb
        </div>
        <div class="">
          Blank - Left for User Application
          <br>
          100Kb
        </div>
      </div>
      <div style="text-align: center">
        <b>External Flash</b>
      </div>
    </div>
  </div>
</div>

*  Current Firmware, executed from internal flash, is responsible for downloading *new* firmware, which is then stored in ext-flash.
*  The Bootloader (discussed below) is responsible for copying over new firmware from ext-flash into internal flash.

<div class="alert alert-info">
  Note:  In the parlance of <strike>our times</strike> TI's BLE literature, this architecture is referred to as "Off-Chip" OTA.
</div>

### Internal Flash
First, let's take a look at how we'll layout our internal flash memory.

<div class="row">
  <div class="col-md-3">
    <div class="mmap-container">
      <div style="text-align: center">
        <b>Internal Flash</b>
        <br>
        Memory Map
        <br>
        128Kb Total
      </div>
      <div class="mmap">
        <div class="bg-success">
          CCFG
          <br>
          88 bytes
        </div>
        <div>
          Blank
          <br>
          &#8818; 20Kb
        </div>
        <div class="bg-danger">
          Current Firmware
          <br>
          100Kb
        </div>
        <div class="bg-success">
          Bootloader
          <br>
          8Kb
        </div>
      </div>
    </div>
  </div>
  <div class="col-md-9">
    <div class="table-responsive">
      <table class="table">
        <thead>
          <tr>
            <th>Flash Region</th>
            <th>Purpose</th>
            <th>Starting Address</th>
            <th>Permanent?</th>
          </tr>
        </thead>
        <tbody>
          <tr class="success">
            <td>CCFG</td>
            <td>
              These 88 bytes are flashed with the bootloader, and used to store some information regarding hardware configuration.  It is important to note that the CCFG region is aligned with the end of flash; it inhabits the very last 88 bytes of the EEPROM.
            </td>
            <td>0x1FFA8</td>
            <td>Yes</td>
          </tr>
          <tr class="">
            <td>Blank</td>
            <td>
              We leave this region empty simply because an even 100Kb for the firmware binaries worked out nicely.  This space could be used to store even larger firmware images if desired.
            </td>
            <td>0x1B000</td>
            <td>No</td>
          </tr>
          <tr class="danger">
            <td>Current Firmware</td>
            <td>
              This is the firmware that the CC26XX executes.  To change the firmware version of a device, simply erase & overwrite this region with firmware code from somewhere else.
            </td>
            <td>0x2000</td>
            <td>No</td>
          </tr>
          <tr class="success">
            <td>Bootloader</td>
            <td>
              The bootloader is the first code to be executed when the CC26XX powers on.  It verifies whether or not the Current Firmware is valid, and if there is a more recent firmware image downloaded in external storage.  If the Current Firmware is corrupt, or if there exists a more recent firmware version in external storage, the bootloader overwrites the Current Firmware with that most recent valid firmware image.  If there are no valid OTA images in external storage, the bootloader overwrites the Current Firmware with a "Golden Image," which is copy of the very first firmware (e.g. from the factory), kept as a permanent backup in external storage.
            </td>
            <td>0x0000</td>
            <td>Yes</td>
          </tr>
        </tbody>
      </table>
    </div>
  </div>
</div>

### External Flash
Now, let's look at the external flash memory map.


<div class="row">
  <div class="col-md-3">
    <div class="mmap-container">
      <div style="text-align: center">
        <b>External Flash</b>
        <br>
        Memory Map
        <br>
        500Kb Total
      </div>
      <div class="mmap">
        <div class="bg-danger">
          OTA Image 3
          <br>
          100Kb
        </div>
        <div class="bg-danger">
          OTA Image 2
          <br>
          100Kb
        </div>
        <div class="bg-danger">
          OTA Image 1
          <br>
          100Kb
        </div>
        <div class="bg-success">
          Golden Image
          <br>
          100Kb
        </div>
        <div class="">
          Blank - Left for User Application
          <br>
          100Kb
        </div>
      </div>
    </div>
  </div>
  <div class="col-md-9">
    <div class="table-responsive">
      <table class="table">
        <thead>
          <tr>
            <th>Flash Region</th>
            <th>Purpose</th>
            <th>Starting Address</th>
            <th>Permanent?</th>
          </tr>
        </thead>
        <tbody>
          <tr class="danger">
            <td>OTA Image 3</td>
            <td>
              A third OTA download slot.
            </td>
            <td>0x64000</td>
            <td>No</td>
          </tr>
          <tr class="danger">
            <td>OTA Image 2</td>
            <td>
              A second OTA download slot.
            </td>
            <td>0x4B000</td>
            <td>No</td>
          </tr>
          <tr class="danger">
            <td>OTA Image 1</td>
            <td>
              First OTA download slot.
            </td>
            <td>0x32000</td>
            <td>No</td>
          </tr>
          <tr class="success">
            <td>Golden Image</td>
            <td>
              A backup of the initial device firmware, issued at the factory.  This is never modified or overwritten, and is only used to restore the device firmware if all 3 available OTA images are invalid, and the internal flash's Current Firmware is also corrupt.
            </td>
            <td>0x19000</td>
            <td>Yes</td>
          </tr>
          <tr class="">
            <td>Blank</td>
            <td>
              We leave the first 100Kb blank in case the user's application also needs ext-flash.  We could of course also easily use this space to increase the number of available OTA slots.
            </td>
            <td>0x0000</td>
            <td>No</td>
          </tr>
        </tbody>
      </table>
    </div>
  </div>
</div>


## Bootloader
The bootloader takes up the first 2 pages (8Kb) of internal flash.  It should never be overwritten, as the OTA images will rely on the bootloader to actually copy firmware between external and internal flash.  The bootloader can be built using the following make target:

```bash
cd examples/cc26xx-ota-bootloader/bootloader
make bootloader.hex
```

### Behaviour & Operation
On boot, the bootloader will first check the internal flash for the current firmware.  It will next recompute the CRC16 shadow over this firmware.  If the CRC shadow matches the CRC value stored in the metadata (computed server-side), then the firmware is deemed valid.  Next, the bootloader checks the external flash in a similar fashion for any OTA images with a version number higher than the current firmware.  If the bootloader finds a newer OTA image, or alternatively if the current firmware is determined to be corrupt from the CRC check, the bootloader will overwrite the internal flash with the newest valid OTA image.

In a worst case scenario, where there are no newer OTA images in external flash, and the internal firmware is also corrupt, the bootloader will overwrite the internal flash with the "Golden Image," which is the firmware located in OTA slot 0.

The bootloader Makefile accepts two optional compiler flags which can be used for intentionally overwriting the Golden Image (OTA slot 0) or the OTA image downloads (OTA slots 1-3).

```bash
cd examples/cc26xx-ota-bootloader/bootloader
make bootloader.hex BURN_GOLDEN_IMAGE=1 CLEAR_OTA_SLOTS=1
```

Compiler Flag | Purpose
---|---
`BURN_GOLDEN_IMAGE=1` | The bootloader will copy the current firmware from internal flash and store it in OTA slot 0 before running any other code.  To flash firmware as the Golden Image, simply merge it with a bootloader thus configured.
`CLEAR_OTA_SLOTS=1` | Use this flag if you want the bootloader to erase all OTA slots in external flash before running any other code.  This will not erase the Golden Image.

<div class="alert alert-danger">
  A device left with a bootloader in one of these override modes will not work as a proper OTA system, as both flags will overwrite things required for the OTA system to function on every power cycle.  If your device seems to be ignoring OTA downloads or failing to recover from corrupted downloads, ensure you are using a bootloader compiled without any flags set!
</div>


### Golden Image
The concept of the Golden Image is like that of the OTA Images -- it is device firmware stored in external flash.  However, unlike OTA images, it will never be overwritten by OTA downloads, and the Golden Image must be manually burned into flash.

To burn a given OTA image into the Golden Image slot, just compile your firmware as if it were a typical OTA image.  However, when you compile the *bootloader*, use the `BURN_GOLDEN_IMAGE=1` compiler flag:

```bash
make bootloader.hex BURN_GOLDEN_IMAGE=1
```

You can then merge the bootloader with your OTA image and flash it as usual.  The `BURN_GOLDEN_IMAGE` flag has a very special effect on the bootloader.  Now, when the device first boots up, the bootloader will copy the current firmware (the OTA image you compiled) from internal flash, into the Golden Image slot of external flash.  This will occur *everytime* the device reboots, however, so it's important to reflash the bootloader with a regular version (compiled without the flag), or else the Golden Image can no longer be assumed to be a fixed backup.

### Clear OTA Download Slots
If you wish to clear all the OTA download slots (1-3) in external flash before executing your firmware, you can compile the bootloader using the `CLEAR_OTA_SLOTS=1` flag:

```
make bootloader.hex CLEAR_OTA_SLOTS=1
```

## Anatomy of an OTA Image
```
metadata + firmware = OTA image
```

"OTA image" is just the binary union of a 256-byte header containing a `OTAMetadata_t` struct, followed by the Contiki firmware that you want to be delivered as the update.

<div class="row">
  <div class="col-md-4 col-md-offset-4">
    <div class="mmap-container">
      <div style="text-align: center">
        <b>Typical OTA Image</b>
      </div>
      <div class="mmap">
        <div class="bg-danger">
          Firmware Binary Code
          <br>
          Up to 99.75Kb
        </div>
        <div class="">
          Blank
          <br>
          240 bytes
        </div>
        <div class="bg-danger">
          Metadata
          <br>
          16 bytes
        </div>
      </div>
    </div>
  </div>
</div>

The purpose of the metadata is to keep track of firmware versions and image health.  It takes the form of a C struct comprising 16 bytes:

```c
typedef struct OTAMetadata {
  uint16_t crc;             //  Result of CRC16 done server-side
  uint16_t crc_shadow;      //  Recalculation of CRC16 executed on download - must match CRC
  uint32_t size;            //  Size of firmware image, in bytes
  uint32_t uuid;            //  Integer representing unique firmware ID
  uint16_t version;         //  Integer representing firmware version
} OTAMetadata_t;
```

<div class="alert alert-info">
Although the total byte-count of each data-type in the <code class="highlighter-rouge">OTAMetadata_t</code> struct would seem to be 14 bytes, GCC will require our C structs to be word-aligned.  The nearest multiple-of-4 to 14 is therefore 16 bytes, and this is the size <code class="highlighter-rouge">OTAMetadata_t</code> will take in memory and flash.
</div>

Why the blank 240 bytes?  The very first object inside Contiki firmware binaries is the vector table (VTOR).  The CC26xx VTOR must be 256-byte aligned.  So, although we only need the first 16 bytes for our metadata, the Contiki code can't actually start until byte 256.

### Creating Metadata
Metadata can be created using the `generate-metadata` program, provided in the `cc26xx-ota-bootloader` example folder.  You must first compile it, and then pass it your firmware .bin file along with some arguments for e.g. desired version and UUID numbers.

**Build generate-metadata**

If `generate-metadata` program doesn't exist yet:

```bash
make generate-metadata
```

`generate-metadata` accepts three command line arguments:

*  The path to the Contiki firmware .bin you want to create metadata for.
*  The version number you want to give the firmware (16 bit hex integer)
*  A universally unique ID (32 bit hex integer)

```bash
#generate-metadata <Contiki firmware .bin file> <fw version number (hex 16)> <fw uuid <hex 32>
generate-metadata firmware.bin 0x00 0xdeadbeef
```

### Merging Metadata
The above process generates a `firmware-metadata.bin` file containing the 256-byte header described above.  To create an OTA Image, we must merge this header together with the original firmware .bin file.  To do this, we can simply use the `srec_cat` utility:

```bash
srec_cat firmware-metadata.bin -binary firmware.bin -binary -offset 0x100 -o ota-image.bin -binary
```

The final `ota-image.bin` will be understood by the `bootloader`, and can be flashed to `0x2000` manually or sent over-the-air from `ota-server.js`.

## OTA Image Server
The purpose of the OTA Image Server is simply to serve the binary data of OTA Images to the Contiki nodes over CoAP.  We will use CoAP's blockwise data transfer mechanism to do this.  Blockwise CoAP messages permit us to send large bodies of information, that may be many times larger than the largest network chunk we can comfortably deal with in our mesh.  In most cases, with 6LoWPAN, that limit is about 64 bytes.  With the resources of a CC2650, we can crank that up to about 256 bytes per REST chunk.  Even so, our firmware is on the order of 100s of kilobytes, so blockwise is the way to go here.

This server can run on any network address that is resolvable by your nodes!  (The OTA server address can be trivially [changed here](https://github.com/msolters/contiki/blob/master/examples/cc26xx-ota-bootloader/apps/ota/ota-download.h#L18).)

It's possible for the Contiki firmware to fail during an update, and only download some subset of the firmware image.  In the event this occurs, the download will continue trying to complete the download starting where it left off.  For this reason, we must communicate to the server what data offset we want to start downloading the firmware image at.  For this, we use the `payload` of the CoAP GET request.

So, in summary, the server will have the following features:

*  Read a local `.bin` file, that represents the new firmware to be delivered OTA (as a nodejs `Buffer()`)
*  Create an CoAP server that listens for GET requests and reads a 32-bit flash address from the request's `payload`
*  Send the requested subset of the firmware image using CoAP blocks (when the `block2` CoAP header option is present in requests)

You can clone the below working example from my [ota-server](https://github.com/msolters/ota-server) repo.  I use Node.JS to implement the OTA server.

**ota-server.js**

```js
var coap = require('coap');
var url = require('url');
var fs = require('fs');

var server = coap.createServer({ type: 'udp6' });

//  Configure the firmware to be served OTA
var firmware_binary = fs.readFileSync( process.argv[2] );

//  Here's where we process CoAP requests for chunks of the firmware_binary
server.on('request', function(req, res) {
  // (1) Parse URL path to see if this is an OTA request
  console.log("Received CoAP request: " + req.url);
  request_parts = url.parse( req.url );
  path_arguments = request_parts.path.split("/");

  if (path_arguments[1] == "ota") {
    // (2) Determine the starting address of this OTA download request
    data_start = req.payload.readUInt32LE(0);
    console.log("Requesting firmware starting from firmware address " + data_start);

    // (3) Don't send data if the request is beyond the size of the OTA image
    if ( data_start <= firmware_binary.length ) {
      res.end( firmware_binary.slice(data_start, firmware_binary.length) );
    }
    return;
  }

});

server.listen( function() {
  console.log("OTA server listening on coap://[::1]:5683");
});
```

This server is super minimal and serves mostly as an example for how to incorporate a Contiki OTA server into your own systems.

This server will respond to GET requests of the form:

```
coap://[bbbb::1]/ota
```

Where the `payload` is the flash address (32-bit, little endian integer) you want to start downloading firmware data at.  So e.g. `coap://[bbbb::1]/ota`, `payload=0x0` would start a CoAP transfer of the entire firmware.  But setting the payload equal to e.g. `0x1000` would start the download on the second page of the new image.


## Adding OTA to Existing Contiki application
It's relatively easy to add OTA download as a feature into your pre-existing Contiki firmware, and to package your firmware as an OTA image to be used over the OTA Image Server.

>  Note:  First, make sure you are working inside this fork; these methods will not work in vanilla Contiki.

### Copy the OTA app to your example
Copy `apps/ota` into your Contiki example's root folder.  This will provide a local apps folder with all the OTA code you need for downloading and performing CRUD operations on OTA images.

### Update Your Makefile
We have to make sure Make sure you have the following lines in your project's makefile:

```
PROJECTDIR?=.
APPDIRS += $(PROJECTDIR)/apps
APPS += er-coap rest-engine ota
OTA=1

CONTIKI_WITH_IPV6 = 1
```

The most important thing is to see that the `apps` folder you copied in the previous step can be located by `APPDIRS`.  That way, `APPS += ... ota` will be able to resolve our OTA app!

<div class="alert alert-info">
  The <b>er-coap</b> app is a dependency of this OTA mechanism.  However, I had to use the modified <b>er-coap</b> app found in the <a href="https://github.com/cetic/6lbr/tree/develop/apps/er-coap">6LBR project</a>, as it is more robust and blockwise-compatible.  That's another important reason you must use this fork of Contiki; or, manually overwrite your <b>contiki/apps/er-coap</b> with the 6LBR version!
</div>

### Update `project.conf`
For CoAP to work correctly, we have to make some defines.  I've found the bare minimum is as follows in my project's `project.conf`:

```c
/*---------------------------------------------------------------------------*/
/* COAP                                                                      */
/*---------------------------------------------------------------------------*/
#undef UIP_CONF_BUFFER_SIZE
#define UIP_CONF_BUFFER_SIZE           1280

/* Disabling TCP on CoAP nodes. */
#undef UIP_CONF_TCP
#define UIP_CONF_TCP                   0

/* Increase rpl-border-router IP-buffer when using more than 64. */
#undef REST_MAX_CHUNK_SIZE
#define REST_MAX_CHUNK_SIZE            256

/* Multiplies with chunk size, be aware of memory constraints. */
#undef COAP_MAX_OPEN_TRANSACTIONS
#define COAP_MAX_OPEN_TRANSACTIONS     2

/* Filtering .well-known/core per query can be disabled to save space. */
#undef COAP_LINK_FORMAT_FILTERING
#define COAP_LINK_FORMAT_FILTERING     0
#undef COAP_PROXY_OPTION_PROCESSING
#define COAP_PROXY_OPTION_PROCESSING   0
```

<div class="alert alert-danger">
  The <b>UIP_CONF_TCP</b> line is the reason I couldn't use my initial OTA app, with HTTP.  HTTP requires that TCP be enabled, but CoAP seems to require it be off!
</div>

### Set Contiki's OTA Server URL

Make sure the IP address of `ota-server.js` is reflected in the `#define OTA_SERVER_IP()` line found inside `apps/ota/ota-download.h` before you compile.  Default value is to look for an OTA server at `bbbb::1`.  

```c
#define OTA_SERVER_IP() uip_ip6addr(&ota_server_ipaddr, 0xbbbb, 0, 0, 0, 0, 0, 0, 0x1)
```

Remember, the CoAP port is by default `5683`.

### Include the OTA Download Headers
Make sure your Contiki app uses the following headers:

```c
#include "ota-download.h"
```

### Start an OTA Download Thread to Update
To actually trigger a CoAP update attempt in Contiki:

```c
process_start(ota_download_th_p, NULL);
```

The logic of when to trigger this process is entirely up to you.  For example, you could trigger the download process in the callback of a COAP request which would be sent to the Contiki node when the server receives new firmware.

Just keep in mind:  when this process is complete, the device will reboot!  Once you start the `ota_download_th` thread, assume the device could reboot at any time.  Also, this version will continue to attempt to complete the download theoretically forever.  Feel free to implement an error catching or retry counting scheme if you like.

### Compile
You should be able to simply compile your app as per usual.  One important rule to follow when compiling firmware as an OTA image though -- the target must be a .bin!  That's because we still need to add the OTA metadata to the firmware image, and the `generate-metadata` tool only works with .bin files.

>  Note:  It's important to use a .bin target because when producing & injecting OTA metadata, we need the raw byte-by-byte firmware image.  An Intel-format .hex file would have to be parsed first.

### Add OTA Metadata
OTA metadata consists of the following:

Metadata Property | Size | Description | Example
Version | `uint16_t` | This is an integer used to represent the version of the firmware.  This is the value used to determine how "new" a firmware update is.  The bootloader will always prefer OTA images with higher version numbers.  You should use a value of 0x0 for your initial factory-given firmware. | 0x0, 0x1, ... 0xffff
UUID | `uint32_t` | This is a unique integer used as an identifier for the firmware release.  This is primarily of use internally, to index software changes or to use as a hash of e.g. the commit # the firmware is based off. | 0xdeadbeef

There are two other OTA metadata properties -- CRC16 value (computed by the provided tool), CRC16 shadow value (computed by the recipient device to verify the image integrity) and firmware size (in bytes).  However, none of these require your direct input.

#### Creating OTA Metadata from the Firmware .bin
I have included a C program that will allow you to easily create OTA metadata, called `generate-metadata`.  When running `make master-hex`, it's automatically built from `generate-metadata.c`.  In case it's not, you can simply run `make generate-metadata`.  See the section on [Creating Metadata](http://marksolters.com/programming/2016/06/07/contiki-ota.html#creating-metadata) for more detailed information.

`generate-metadata` accepts 3 arguments; the path to the firmware .bin, the version number and the UUID.

>  Note:  Both version number and UUID should be given as **hex** integers.  Example usage:

```bash
make generate-metadata
./generate-metadata ota-image-example/ota-image-example.bin 0x0 0xdeadbeef
```

After running the program, you will get a `firmware-metadata.bin` file in the same directory as the `generate-metadata` executable.

#### Merging OTA Metadata with your Firmware Binary
Now, to complete the construction of your custom OTA image, all you need to do is merge the `firmware-metadata.bin` with the firmware .bin.  To do that, use the `srec_cat` utility:

```bash
srec_cat firmware-metadata.bin -binary ota-image-example/ota-image-example.bin -binary -offset 0x100 -o firmware-with-metadata.bin -binary
```

Obviously, you should replace `ota-image-example/ota-image-example.bin` with your own firmware binary.  This command will then ouput a final .bin file, `firmware-with-metadata.bin`.  This is a complete OTA image!  This is the type of .bin file that can be loaded using e.g. `ota-server.js`.  It contains appropriate metadata header and a Contiki app compiled with the `OTA=1` flag.

### Merge the Bootloader and the OTA Image
For the initial flash operation, we will need our Sensortag to have both a working bootloader and the initial OTA image .bin we just created.  To build *just* the bootloader, run

```
cd examples/cc26xx-ota-bootloader/bootloader
make bootloader.hex
```

This will leave a `bootloader.hex` in the `/bootloader` folder.  Finally, we'd like to merge the bootloader and OTA image binaries into one .hex file.  To do that, we can once again use the `srec_cat` command:

```bash
srec_cat bootloader/bootloader.hex -intel -crop 0x0 0x2000 0x1FFA8 0x20000 firmware-with-metadata.bin -binary -offset 0x2000 -crop 0x2000 0x1B000 -o firmware.hex -intel
```

While you may change the location of your `bootloader.hex` or `firmware-with-metadata.bin`, it is important to keep all numeric arguments as they are!  The final file produced by this operation is `firmware.hex`.  This will represent a working bootloader, as well as your own firmware compiled as an OTA image with OTA metadata!
