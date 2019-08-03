---
layout:     post
title:      "GalliumOS + HDPI Display (Pixel 2015)"
date:       2016-05-13
categories: programming
sidebar:    true
---

## Pixel 2 is a Special Child
The Chromebook Pixel 2 is, without a doubt, an edge case where Chromebooks are concerned.  Especially if you are using the LS version, as I am.

Simply put, the whole idea behind a Chromebook is to make it affordable.  Small amounts of RAM, and slower processors.  For this reason, any replacement OS for Chromebooks should be something designed with constrained system resources in mind. Accordingly, GalliumOS ships with the XFCE desktop.  This is significantly less heavy-weight than other desktops such as Gnome or Unity.

The Pixel's max screen resolution is 2560x1700.  You may notice that, when first booting GalliumOS on the Pixel, you can't read anything!  2560x1700 is such a high resolution on a 13" screen, window controls (such as close/minimize/maximize) and menu items are practically microscopic!  The most direct solution is to go to `Settings Manager > Display` and simply choose a more reasonable resolution, such as 1600x1062.

However, this simply means you are trading out readability for a fuzzier experience.  By reducing the overall system display resolution, you are not making full use of the HDPI screen.  1600x1062 is still an amazing resolution, and there's nothing wrong with it, but why did you pay $1,300 for a dream machine that isn't being used to the full extent of its powers?

Most modern Linux desktop managers provide workarounds for this.  For example, in Gnome and Unity, there are "UI Scaling" sliders in the Display settings.  This allows you to basically use an ultra-high resolution, and then scale up the size of literally *the entire interface.*  This works great.  It's baked into GTK3.

Unfortunately, GalliumOS ships with XFCE, not Unity or Gnome.  And XFCE, in the name of resource efficiency, is using the GTK2 engine for theming and rendering its window manager!  This means we can't just "magnify" our whole UI.

## Tweak GalliumOS to be HDPI-Friendly
So, in a nutshell, we have a set of modifications that will allow the GalliumOS experience to be usable even at full 2560x1700 resolution (instead of one master slider).  Word on the street is that GalliumOS will eventually be moving to GTK3-friendly window manager -- but again, keep in mind that GalliumOS must always make sure to be compatible with the bulk modulus of Chromebook hardware.  As long as Chromebooks are mid-range affordable products, compatibility and support for more luxurious hardware will always be on the back burner (officially).

## OS-level HDPI Tweaks

### Use the Native 2560x1700 Resolution
First, make sure you are using the largest system resolution available.  Go to `Settings Manager > Display`, and then select 2560x1700 from the `Resolution` dropdown.

![Gallium HDPI Display Configuration]({{site.url}}/assets/images/gallium-hdpi-display.png)

### Increase System-Wide Fonts DPI
While we cannot scale the DPI of all UI elements easily with GTK2, we can at least scale all fonts to be HDPI-friendly!  Go to `Settings Manager > Appearance`, and then select the `Fonts` tab.  I make two changes here:

*  Set the Custom DPI to `188` (about twice the default, 96)
*  Set Default Font down to `9` (I find there's a big difference between 10 and 9 once the DPI has been increased)

![Gallium HDPI Font Configuration]({{site.url}}/assets/images/gallium-hdpi-font.png)

### Use a Modified Arc Theme
Due to the fact that XFCE is using GTK2 themes, UI elements such as window controls, buttons and check boxes cannot be trivially "scaled up."  Each element must be manually modified in the theme.  I found that Github user [@af2005](https://github.com/af2005) has already made amazing contributions to this effort by [forking the official Arc theme](https://github.com/af2005/Arc-theme-HiDPI) and making the window controls significantly larger!

Arc has had several hundred commits since then, however, and window controls are not the only thing that require scaling.  Therefore, I have merged in both [@af2005](https://github.com/af2005)'s changes as well as the subsequent work from Arc official, and have continued to make improvements where I can.  This new HDPI-friendly theme is located at my [arc-hdpi repo](https://github.com/msolters/arc-hdpi).

This Arc theme can be installed in parallel with the `Arc*-GalliumOS` themes that come with Gallium.

1.  Clone and install the modified Arc theme.

    ```bash
    git clone https://github.com/msolters/arc-hdpi
    cd arc-hdpi
    ./autogen.sh --prefix=/usr
    sudo make install
    ```
1.  Select either `Arc`, `Arc-Dark`, or `Arc-Darker` in `Window Manager > Theme` and  `Appearance > Style`:
    ![Gallium HDPI HDPI Arc]({{site.url}}/assets/images/gallium-hdpi-arc.png)

### Panel
Right click on the Panel to open the menu, then `Panel > Panel Preferences`.

*  **Panel Height**
    `Display > Measurements > Row Size = 70px`
    ![Gallium HDPI Panel Configuration]({{site.url}}/assets/images/gallium-hdpi-panel.png)
*  **Window Buttons**
    `Items > Window Buttons > Appearance > Show button labels > Off`
    ![Gallium HDPI Window Buttons]({{site.url}}/assets/images/gallium-hdpi-window-buttons.png)
*  **Notification Area**
    `Items > Notification Area > Maximum icon size = 60px`
    ![Gallium HDPI Notification Area]({{site.url}}/assets/images/gallium-hdpi-notification-area.png)

### Use Alt-Window Resizing
One of the biggest pains with HDPI windows is resizing them -- you have to hover your pointer in such a way as to click on some impossibly thin 1px window border.  If you didn't already know about them, the following keyboard shortcuts will change your life forever:

*  **Resize**:  Hold `Alt` and right-click drag anywhere in a window.
*  **Drag**:  Hold `Alt` and left-click drag anywhere in the window.


## Application-level HDPI Tweaks

### Use Chrome, not Chromium!
GalliumOS comes bundled with Chromium.  However, Chromium has a difficult time rendering on HDPI screens - it won't obey the font DPI settings above.  Luckily, the latest Chrome binaries work out-of-the-box on HDPI screens!  I highly recommend you use [Chrome](https://www.google.com/chrome/browser/desktop/) in lieu of Chromium:

![GalliumOS at 2560x1700]({{ site.url }}/assets/images/gallium-hdpi-chrome.png)

### Atom
Atom is an amazing text editor.  However, it's also Chrome-based, so you will encounter the same problem as Chromium above.  Fortunately, there is a great Atom plugin called [HIDPI](https://atom.io/packages/hidpi) that will scale Atom's entire UI.  (Note: this may require you to restart Atom after installing)

![Atom at 2560x1700]({{ site.url }}/assets/images/gallium-hdpi-atom.png)
