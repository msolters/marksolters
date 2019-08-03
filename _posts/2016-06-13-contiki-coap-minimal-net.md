---
layout:     post
title:      "Contiki - CoAP over minimal-net"
date:       2016-06-13
categories: programming
css: ['open-source.css']
sidebar: true
---

`minimal-net` is a Contiki board target used to build a Contiki application that runs natively, in your terminal.  It also configures a very basic network between the virtual device and your local machine, which manifests on the host computer as the network interface `tap0`.

I've been using `minimal-net` to quickly write, compile & run Contiki projects implementing CoAP communications.

While my Contiki nodes were CoAP clients, I wanted them to communicate with a server also running natively on the host computer:

![contiki coap client and nodejs server]({{site.url}}/assets/images/contiki-minimal-net-coap.png)

Unfortunately, for whatever reason, the tools provided in the example folder never seemed to get any kind of network communication working.

After some trial and error I hit upon a method that will allow your native, `minimal-net` Contiki apps to speak with servers you are running on your local machine.


## Local CoAP with ContikiOS
We are going to implement a simple local development environment, consisting of a CoAP server running on a host computer, with natively-compiled Contiki running and communicating with that same server via a `tap0` interface.  The client we're going to use is found inside Contiki's `examples/er-rest-example` folder (see below).

### coap-server.js

NodeJS is my preference, so I use the [node-coap](https://github.com/mcollina/node-coap) NPM package by [mcollina](https://github.com/mcollina).  It's based on Node's `http` package.


<div class="repo-list row">
  {% for repo in site.github.public_repositories  %}
    {% if repo.name == "coap-server" %}
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


```js
var coap = require('coap');
var url = require('url');

var server = coap.createServer({ type: 'udp6' });

//  Handle incoming CoAP requests
server.on('request', function(req, res) {
  console.log("Received CoAP request: " + req.url);

  //  (1) Here's how to parse URL path for arguments
  var request_parts = url.parse( req.url );
  var path_arguments = request_parts.path.split("/");
  // the first "arg" is always blank due to the leading / in the URL path
  delete path_arguments[0];

  //  (2) Construct response message
  var responseMsg = "That request had " + (path_arguments.length-1) + " arguments. [ ";
  for ( a in path_arguments ) {
    responseMsg += path_arguments[a] + " ";
  }
  responseMsg += "]";

  //  (3) Send response message to CoAP clients
  console.log( "\t" + responseMsg );
  res.end(responseMsg);
});

server.listen( function() {
  // We didn't specify a host or port, the default for
  // ipv6 CoAP is [::1]:5683.
  console.log("OTA server listening on coap://[::1]:5683");
});
```

This server is just going to answer all incoming requests with a response saying how many arguments the URL had.

### Configure Server
The NodeJS server will match *any* IPv6 address that is the same as `localhost`.  The question is, which of the host computer's network interfaces is visible to the Contiki nodes running in `minimal-net`?

The `minimal-net` target causes Contiki binaries to create a new `tap0` network interface on your local machine when executed.  The `tap0` interface is visible to Contiki.  By default, it's given just a link-local (`fe80`) IPv6 address.

![the tap0 interface created by minimal-net]({{site.url}}/assets/images/minimal-net-tap0.png)

<div class="alert alert-danger">
  Warning:  Keep an eye on <b>ifconfig</b>.  If you find your <b>tap0</b> interface is disappearing, or fails to appear, it may be your computer's network manager.  Try to disable your host OS's networking or turning off automatic network management.
</div>

However, this link-local IP address will be different every time you start the Contiki nodes.  So, we can't use this value in our firmware as the server address.  But, we can add our own IP address to `tap0`, and then just use the same one in our Contiki source!

The `er-rest-example/Makefile` contains a target called `connect-minimal` that will add a known IP address to that `tap0 interface`.  It comes out-of-the-box with an IPv6 address looking something like this:

```bash
connect-minimal:
	sudo ip address add fdfd::1/64 dev tap0
```

I encountered no luck reaching this IP `fdfd::1` from my Contiki nodes.  I don't know why.  Investigating further, the Makefile contains this cryptic hint:

![minimal-net is broken in contiki]({{site.url}}/assets/images/minimal-net-broken.png)

Hmm.  After some experimentation, I found that link-local IPs *could* be resolved by the virtual Contiki nodes.  I randomly picked a `fe80::/64` address and added it to the `connect-minimal` target:

```bash
connect-minimal:
  sudo ip address add fdfd::1/64 dev tap0
  sudo ip address add fe80::dead:beef/64 dev tap0
```

Now, we can use `make connect-minimal` to set a hardcoded IP address for our `tap0` interface.

### Setting Server IP in Contiki
Next, we need to enter the same IP in our Contiki firmware.  We are using the `er-example-client.c` program included in the `examples/er-rest-example` folder of the Contiki tree.  Near the top, you can override the `SERVER_NODE` macro to hard code your CoAP server's IP address.

![the coap server ip macro in contiki source code]({{site.url}}/assets/images/minimal-net-server-ip.png)

Here, you can see how we commented out the default `SERVER_NODE`, and filled in our own that contains the full IPv6 address `fe80:0:0:0:0:0:dead:beef`.

### Running Contiki
Now, the Contiki nodes can be built & started by running:

```bash
make TARGET=minimal-net er-example-client
sudo ./er-example-client.minimal-net
```

And then in a different terminal, but still inside `examples/er-rest-example`:

```bash
make connect-minimal
```

This may require your password.  But inspecting with `ifconfig`, you should find your `tap0` interface now has a fixed IPv6 address of `fe80::dead:beef`:

![minimal net tap0 static ip]({{site.url}}/assets/images/minimal-net-tap0-deadbeef.png)

### Start the Server
Finally, you can start the NodeJS server with a simple

```bash
npm install
node coap-server.js
```
