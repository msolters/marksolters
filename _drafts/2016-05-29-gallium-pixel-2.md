---
layout:     post
title:      "GalliumOS + HDPI Display (Pixel 2015)"
date:       2016-05-13
categories: programming
sidebar:    true
---

## The Chromebook Pixel Hardware is Beyond Reproach

Google's Chromebook Pixel (2015) is undoubtedly one of the best computers I've ever bought.  Its build is immaculate -- the metal chassis, the variable backlit keyboard, the HDPI screen.  I could go on, but it would be redundant.  It seems most of the internet agrees on these points.

The one drawback of the Pixel 2 is that it ships with ChromeOS.  No matter where you look for Pixel reviews, you'll find people complaining that $1,300 is not an acceptable price for the functionality that ChromeOS offers.  While I agree that ChromeOS is severely limiting, it is untrue to say that the Pixel 2 is not worth every penny it costs.  The reason is simple:


## You don't have to use ChromeOS.
The Pixel is just a computer.  A giant calculator.  You can install any operating system on it you want, up to the limit of what drivers that OS supports, or that you are willing to write.  There are many paths to full Linux freedom:

*  For the ultra-lazy, you can get a full Linux desktop running on a Chromebook using the [Crouton](https://github.com/dnschneid/crouton) tool.  You don't even have to drop ChromeOS.  This solution works great as a test drive -- and it supports many different Linux flavors.  XFCE, Unity, Gnome, etc.
*  However, eventually you may want to free up that precious internal SSD space, and drop ChromeOS entirely.  The best way to do this would be with a tool like [chrx](https://chrx.org/).


## I Recommend Using Gallium OS
Now, this article is not intended as a guide to installing Linux as the sole OS on a Pixel 2.  Rather, it's to help with the steps after installation -- making use of your Pixel's amazing hardware in an operating system not specifically designed for it.  In particular, **this article is going to assume you are already using Gallium OS.**

From the ChromeOS `shell`, GalliumOS can be installed with a single command:

```bash
curl -Os https://chrx.org/go && sh go -v
```
