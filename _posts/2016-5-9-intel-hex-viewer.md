---
layout:     post
title:      "Parse & View Intel-format Hex with Python"
date:       2015-05-9
categories: programming
css: ['open-source.css']
sidebar: true
---

## Viewing HEX File Binary Sequentially


<div class="repo-list row">
  {% for repo in site.github.public_repositories  %}
    {% if repo.name == "intel-hex-viewer" %}
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

Every once in a while you have a `.hex` file and you just want to see the actual sequential memory layout, as you would get by using `hexdump` on a `.bin`.

HEX files, unfortunately, are larger and more complicated than the actual binary data.  HEX files are actually the binary information, plus extra information that allows you to map the binary to various memory addresses.  This allows us to escape e.g. long periods of 0, as we don't have to explicitly include continuous information.

There are various formats of HEX formats.  I'm focusing only on [Intel-format HEX](https://en.wikipedia.org/wiki/Intel_HEX), which is what I deal with a lot with GCC on ARM.

This python script allows you to parse a HEX file, provided as an argument, and outputs a sequential `hexdump`-style memory map of the binary content.

## Usage

```bash
python view-hex.py example.hex
```

## Example Output
![HEX viewer output]({{ site.url }}/assets/images/hex-viewer-output.png)

## Breakdown
The entire program is very brief.  We basically loop over a given file, and parse its HEX records using a helper function.

```python
import sys

#
#   parse_hex_line extracts information out of
#   individual HEX records passed as the arg line.
#
def parse_hex_line( line ):
    if len( current_line ) == 0: return
    bytecount = int( line[0:2], 16 )
    address = int( line[2:6], 16 )
    rec_type = int( line[6:8], 16 )

    rec_output = str(hex(address)) + '\t' + str(bytecount) + '\t'
    if rec_type == 0:
        rec_output += 'data'
        rec_output += '\t\t' + line[8:(8+2*(bytecount))]
    elif rec_type == 1:
        rec_output += 'end of file'
    elif rec_type == 2:
        rec_output += 'ext segment addr'
    elif rec_type == 3:
        rec_output += 'start segment address'
    elif rec_type == 4:
        rec_output += 'ext linear addr'
    elif rec_type == 5:
        rec_output += 'start linear address'
    print rec_output

#   (1) Open the Hex File
hex_file_path = sys.argv[1]
print "Parsing " + hex_file_path
hex_file = open(hex_file_path, "rb")

#   (2) Analyze the hex file line by line
current_line = ""
try:
    byte = "1" # initial placeholder
    print "Address\tLength\tType\t\tData"
    while byte != "":
        byte = hex_file.read(1)
        if byte == ":":
            #   (1) Parse the current line!
            parse_hex_line( current_line )
            #   (2) Reset the current line to build the next one!
            current_line = ""
        else:
            current_line += byte
    parse_hex_line( current_line )
finally:
    hex_file.close()
```

### 1.  Read .hex File as Binary
First, we examine the argument passed to the python script to determine the .hex file path.  Then, we open the file as read-only (`r`) and binary (`b`).

```python
import sys

#   (1) Open the Hex File
hex_file_path = sys.argv[1]
print "Parsing " + hex_file_path
hex_file = open(hex_file_path, "rb")
```


### 2.  Read HEX Records From File
A HEX file consists of a series of records, which are just blobs of binary data ("payload") with information describing that data's purpose and destination address in flash.  Each record is terminated by a `:` character.

Therefore, when reading from our .hex file, we construct our sequential binary data by reading and then parsing each HEX record one at a time, until the end of the file.

```python
#   (2) Analyze the hex file line by line
print "Address\tLength\tType\t\tData"
current_line = ""
try:
    byte = "1" # initial placeholder
    while byte != "":
        byte = hex_file.read(1)
        if byte == ":":
            #   (1) Parse the current line!
            parse_hex_line( current_line )
            #   (2) Reset the current line to build the next one!
            current_line = ""
        else:
            current_line += byte
    parse_hex_line( current_line )
finally:
    hex_file.close()
```

### 3.  Analyze Each HEX Record
For each record that we read from our file, we next pass it to `parse_hex_line( line )`, where we then analyze the record and add a line to our binary dump table.

We know where each HEX record property is to be found by examining [the Intel HEX specification](https://en.wikipedia.org/wiki/Intel_HEX#Record_types).  The first 8 bytes will give us the bytecount (length of payload), the flash address of the payload, and the record type which tells us what the meaning of the payload is.

```python
def parse_hex_line( line ):
    if len( current_line ) == 0: return
    bytecount = int( line[0:2], 16 )
    address = int( line[2:6], 16 )
    rec_type = int( line[6:8], 16 )

    rec_output = str(hex(address)) + '\t' + str(bytecount) + '\t'
    if rec_type == 0:
        rec_output += 'data'
        rec_output += '\t\t' + line[8:(8+2*(bytecount))]
    elif rec_type == 1:
        rec_output += 'end of file'
    elif rec_type == 2:
        rec_output += 'ext segment addr'
    elif rec_type == 3:
        rec_output += 'start segment address'
    elif rec_type == 4:
        rec_output += 'ext linear addr'
    elif rec_type == 5:
        rec_output += 'start linear address'
    print rec_output
```

All records have their type and payload length printed.

However, the payload is only printed if the record is a `data` type.  All other record types are metadata used to keep track of other things important to flashing, such as keeping track of memory offsets etc.  This metadata would never appear in the actual flash target the HEX file is flashing; so we do not print this data to the table.
