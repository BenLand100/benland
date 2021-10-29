---
title: 'Raspberry Pi IPv4/IPv6 router for a dual WAN household'
date: '2021-10-28'
categories: 
  - Sysadmin
description: How to use a Raspberry Pi running Gentoo as a router for a second WAN on a home network.
slug: raspberry-pi-router
toc: true
---

When I ended up with a second connection to the internet (courtesy of being a Comcast employee), there was a potentially painful decision to make.
Xfinity includes a lot of streaming features, which require being _on Xfinity's network_ to utilize. 
Key here is the ability to turn many streaming devices (including a Roku) into a live and on-demand streaming platform for TV with the Xfinity Stream app.
So, do I convert the entire home network over to Comcast's asymmetric cable network, or do I keep the symmetric gigabit fiber connection already in place and miss out on streaming?
Fortunately, there is a third option: connect the streaming devices to the Xfinity network, and maintain the symmetric gigabit fiber for the rest of the machines.
What's better is that it's totally possible to accomplish this with consumer networking devices, without having to purchase (much) new hardware.

## Initial conditions

Prior to the second WAN acquisition, I had a Netgear R6700v3 and a TP-Link Archer C7 both running [DD-WRT firmware](https://dd-wrt.com/). 
The R6700 was the primary router, connected to the gigabit fiber WAN, and hosting the 2.4/5GHz WiFi for the majority of the house, while the Archer C7 was wired in bridge mode to the R6700's LAN as a wireless access point in the office upstairs.
This resulted in gigabit wired in critical locations, and respectable 600+mbit 5GHz performance everywhere that mattered.
Everywhere else had reasonably fast 2.4GHz coverage.

### Exploring dual WAN on single device

In theory it is possible to have [a second WAN under DD-WRT firmware](https://wiki.dd-wrt.com/wiki/index.php/Dual_WAN_with_failover), but in practice, I was not able to get this working on the R6700.
In fact, I encountered a lot of issues on the R6700 when trying to do things a bit outside of the norm. Adding additional virtual LANs (VLANs), or bridging VLANs and virtual wireless access points (WAPs) brought the router to a crawl, or didn't work at all.
Suspecting there was something afoul with the recent DD-WRT builds for the R6700v3, I decided to abandon my decade+ of being a DD-WRT fanboy, and tried out [Fresh Tomato](https://freshtomato.org/) on the R6700. 

Fresh Tomato, besides having a silly name, was easy to setup, and worked out of the box.
The experience was pleasant enough that I can safely say that in 2021, I'd recommend Fresh Tomato over DD-WRT for those with Broadcom devices.
Much to my surprise, it also had good support for configuring VLANs and dual WANs, which also worked out of the box.
The only downside here is that the GUI presupposed that I was either going to load balance on my two WAN interfaces, or use one as a failover when the other went down. 
My use case, instead, was to use both simultaneously and exclusively, for different network network segments.

After a while of fiddling around with Fresh Tomato's `iptables` rules in dual WAN mode, I decided it might be easier to stick with one WAN interface on the consumer-grade routers. 
The nail in the coffin was that I could not seem to get a DMZ host exposed to both WANs (or either WAN, really) while in dual WAN mode.
So, back to gigabit-only on the R6700.

## VLANs and trunk lines

The ultimate goal here is to have two separate networks on my network devices, and the WAN being chosen by which network one connects to.
The way to accomplish this is to configure two separate VLANs, which DD-WRT on my Archer C7 and Fresh Tomato on my R6700 both supported.
To get these VLANs propagated throughout the house, the port on each router with the ethernet cable linking them must be configured as a VLAN tagged trunk line, so that the packets from each VLAN can be bridged between the two routers without having to run two cables.
I opted for using the WAN port on the Archer C7 as the trunk, and LAN port 1 on the R6700 as the trunk.
This trunk transmitted VLAN1 (gigabit) and VLAN3 (Xfinity).
VLAN2 was reserved for the WAN connection on the R6700. 
Each router then bridged the existing (primary and virtual) WAP to VLAN1 and created a new virtual WAP bridged to VLAN3.

The R6700 continued hosting its gigabit WAN, and serving as a gateway from VLAN1 to the WAN (VLAN2).
All that remained  was to provide a gateway to the Xfinity WAN for VLAN3. 

## A Raspberry Pi 3B router

I've had a [Raspberry Pi 3B](https://www.raspberrypi.com/products/raspberry-pi-3-model-b/) for a long time, and hadn't really done anything useful with it.
Should you use a Raspberry Pi as a home router? 
Absolutely not, unless it's a 4+ with higher bandwidth and USB3, but I already had it, and wasn't expecting the Xfinity internet to do much more than stream to one or two devices.
Long ago I setup my Linux distribution of preference, Gentoo, on my RPi, so I had all the tools necessary to do any kind of routing I needed, but presumably Rasbian or your distribution of choice could install enough packages to do the same.

I did buy two TP-Link USB to gigabit Ethernet converters, primarily so that the lights on my router and modem would be the "right color" (a gigabit link).
Do not expect more than ~200mbit one-way throughput on the RPi3.
Receiving and sending simultaneously (as a router does) knocks this down to 100mbit.

The RPi is connected to LAN port 2 of the R6700, which is configured as a VLAN1+VLAN3 tagged trunk line just like the port to the Archer C7.
This will give the RPi access to both VLANs, which is important, because I also use the RPi as the DMZ host for my VLAN1 network.
This trunk line is connected to the `eth2` device on the RPi, while `eth1` is the Xfinity WAN connection via a cable modem.
`eth0` - the RPi's built-in 100mbit ethernet connection - is left disconnected.

### Gentoo's Netifrc configuration

[Netifrc](https://wiki.gentoo.org/wiki/Netifrc) in Gentoo is probably the slickest, most comprehensive, and most concise network configuration of any Linux distribution.
All you really need to know is what subnets you want on which devices, and convenient init scripts can bring interfaces up and down based on a global config file. 
On `eth2`, my gigabit VLAN1 (`eth2.1`) runs on subnet `192.168.1.0/24` with a primary gateway of `192.168.1.1` (the R6700 - with the RPi being `192.168.1.3`), and the Xfinity VLAN3 (`eth2.3`) will be subnet `192.168.2.0/24` using the RPi as a default gateway `192.168.2.3`.
Because Xfinity assigns IPs via DHCP, `eth1` can be auto-configured with `dhcpd`, which will set a default gateway as upstream suggests.
The only complexity comes from the RPi being the DMZ host for the R6700's network. 
This means WAN packets will be arriving on `eth2.1` targeting the RPi's internal IP `192.168.1.3`, and the responses from this IP should leave via `eth2.1` using the R6700 as the gateway.
To account for this, policy based routing is utilized, and an alternate routing table `169` is configured with the R6700 as the default route.
Any packets where the `from` IP matches the subnet `192.168.1.0/24` are send to this alternate table for routing decisions.

All of this is accomplished with the following script, and Gentoo-provided `/etc/init.d/net.eth{1,2}` scripts are handled by init to bring up the network.
```bash
config_eth1="dhcp"
rc_net_eth1_need="net.eth2"

config_eth2="null"
vlans_eth2="1 3"
config_eth2_1="192.168.1.3/24
               fd01::3/64"
config_eth2_3="192.168.2.3/24
               fd02::3/64"
rules_eth2_1="from 192.168.1.0/24 lookup fios"
routes_eth2_1="default via 192.168.1.1 table fios
               192.168.1.0/24 dev eth2.1 src 192.168.1.3 table fios"
routes_eth2_3="192.168.2.0/24 dev eth2.3 src 192.168.2.3 table fios"
```
You'll notice that I have assigned a static IPv6 address to the two internal VLANs. 
I'll explain these later in the IPv6 section, but suffice to say they are in the unique local address `fd00::/8` block that is not globally routable, and are analogous to the `192.168.0.0/16` block in IPv4.

After bringing up all the interfaces with the Netifrc scripts, `ip route show` produces:
```plaintext
default via 73.141.248.1 dev eth1 proto dhcp src [wan_ip] metric 3 
73.141.248.0/21 dev eth1 proto dhcp scope link src [wan_ip] metric 3 
192.168.1.0/24 dev eth2.1 proto kernel scope link src 192.168.1.3 
192.168.2.0/24 dev eth2.3 proto kernel scope link src 192.168.2.3 
```

And the slightly simpler routing table `ip route show table 169`:
```plaintext
default via 192.168.1.1 dev eth2.1 metric 6 
192.168.1.0/24 dev eth2.1 scope link src 192.168.1.3 metric 6 
192.168.2.0/24 dev eth2.3 scope link src 192.168.2.3 metric 7 
```

Along with the rule that triggers table `169` from `ip rule`:
```plaintext
0:      from all lookup local
32765:  from 192.168.1.0/24 lookup 169
32766:  from all lookup main
32767:  from all lookup default
```

And `ip -4 addr` gives the IPv4 addresses (will revisit IPv6 shortly):
```plaintext
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN group default qlen 1000
    inet 127.0.0.1/8 brd 127.255.255.255 scope host lo
       valid_lft forever preferred_lft forever
3: eth1: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc pfifo_fast state UP group default qlen 1000
    inet [wan_ip]/21 brd 255.255.255.255 scope global dynamic noprefixroute eth1
       valid_lft 173194sec preferred_lft 129994sec
6: eth2.1@eth2: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue state UP group default qlen 1000
    inet 192.168.1.3/24 brd 192.168.1.255 scope global eth2.1
       valid_lft forever preferred_lft forever
7: eth2.3@eth2: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue state UP group default qlen 1000
    inet 192.168.2.3/24 brd 192.168.2.255 scope global eth2.3
       valid_lft forever preferred_lft forever
```

#### Reverse path filtering

Note: this routing doesn't pass strict reverse path filtering requirements, for reasons I didn't bother verifying.
It does pass loose reverse path filtering, so I modified `/etc/sysctl.conf` accordingly:
```bash
net/ipv4/conf/default/rp_filter = 1
net/ipv4/conf/all/rp_filter = 1
net/ipv4/conf/eth2/rp_filter = 2
net/ipv4/conf/eth2.3/rp_filter = 2
net/ipv4/conf/eth2.1/rp_filter = 2
```

#### Enabling packet forwarding

While discussing `sysctl` settings, I should note that typically packet forwarding is disabled for security.
Packet forwarding is critical for a router, and can be set up securely.
Enable packet forwarding in `/etc/sysctl.conf`, but definitely take steps mentioned in later sections to securely forward packets.
```bash
net/ipv6/conf/all/forwarding = 1
net/ipv4/ip_forward = 1
```

### IPv4 local dynamic host configuration protocol

Since the RPi is managing this VLAN3 network, it also needs to assign IPv4 addresses to any connecting clients.
The program `dnsmasq` makes this a breeze, and graciously runs a caching DNS server as well.
I'll allow clients on VLAN1 to access the DNS server, but only assign IPs in the `192.168.2.0/24` subnet to VLAN3.
Please consult additional documentation for securing `dnsmasq`, but the following are the critical lines for getting it working.

```bash
interface=eth2.3
interface=eth2.1
no-dhcp-interface=eth2.1
dhcp-range=eth2.3,192.168.2.100,192.168.2.250,48h
```

Now when a client connects and sends an DHCP(v4) request over the network, the `dnsmasq` server will respond with a unique IP for that client, typically tied to its MAC address.

### IPv6 local router advertisements

Since I haven't mentioned IPv6 in any great detail yet, let me describe how it's setup.
IPv6 adoption is long-overdue, but Xfinity is forward-thinking enough to assign `::/64` prefixes to anyone that wants them.
While change can be daunting, IPv6 is actually quite a bit simpler to run than IPv4.
`dhcpd` comes preconfigured to be able to solicit IPv6 addresses for a typical client, and the Gentoo Netifrc above already does that.
To act as a router as well as a client requires only a slight tweak to its configuration, which will acquire routed prefixes from the upstream ISP.

Unlike IPv4 where `dhcpd` solicits a single address, and NAT takes care of the local network, there are more than enough IPv6 addresses in the $2^{128}$ element address space to go around.
With IPv6, upstream routers first assign an address to the router, and will then allow you to request entire `::/64` (or larger) subnets for internal networks.
The upstream routers will then forward any packets destined for your subnets to your router, making all devices on the entire IPv6 internet addressable by all other devices.

Because I can, I decided to assign a prefix to both VLANs, just in case VLAN1 devices want IPv6 connectivity (the gigabit fiber ISP doesn't provide IPv6 yet). 
A small addition to a standard `dhcpd` config will make this happen.
```plaintext
interface eth1
    ipv6rs
    iaid 0
    ia_na
    ia_pd 1/::/64 eth2.1/0/64
    ia_pd 2/::/64 eth2.3/0/64
```
This was the most archaic config file I had to deal with in this whole endeavor, so here's the same thing with comments for anyone seeking advice on the matter:
```plaintext
interface eth1 #for WAN interface eth1 only
    ipv6rs #send an ipv6 router solicitation to get DHCPv6 server info
    iaid 0 #zero out the default identifier (Xfinity required this, ymmv)
    ia_na #request a globally routable ipv6 address from the ISP's DHCPv6 for eth1 (uses default identifier)
    ia_pd 1/::/64 eth2.1/0/64 #request a ::/64 prefix using identifier 1, and assign the whole thing to eth2.1
    ia_pd 2/::/64 eth2.3/0/64 #request a ::/64 prefix using identifier 2, and assign the whole thing to eth2.3
```
My understanding is that these `iaid` identifier values shouldn't matter, but should be unique within this DHCP request.
Xfinity seemed to respond poorly to an `ia_na` not using `iaiad 0`, and seemed to expect subsequent `ia_pd` to use sequentially numbered `iaid`.
The first argument is a hint for what size subnet to request. 
Xfinity only supports `::/64` currently. 
Remaining arguments allow automatic subnetting to different interfaces, though subnetting doesn't make a lot of conventional sense past `::/64`, so I simply request two prefixes, and assign them directly to the two interfaces.

Now that the RPi can acquire an address for itself and routed subnets for its interfaces, all that remains is to "assign" IPv6 addresses to clients.
ISPs make use of DHCPv6 to keep track of which clients have what address for routing purposes.
The local subnet is much, much simpler, and each client can essentially choose a random 64bit number to pad out the `::/64` prefix as its address, with a tiny chance of overlap ($\frac{N}{2^{64}}$ for $N$ clients on the subnet, to be precise).
This is nominally how stateless address auto configuration (SLAAC) works.
A client sends a broadcast packet asking for a router on the local link to send the prefix, along with any other network info, and the client assigns itself an address in the prefix.
The program in Linux which sends this router advertisement is `radvd`, and is configured as follows:
```plaintext
interface eth2.3 {
  AdvSendAdvert on;
  MinRtrAdvInterval 3;
  MaxRtrAdvInterval 10;
  prefix ::/64 {
    AdvOnLink on;
    AdvAutonomous on;
    AdvRouterAddr on;
  };
  prefix fd02::/64 {
    AdvOnLink on;
    AdvAutonomous on;
    AdvRouterAddr on;
  };
  RDNSS fd02::3 {
  };
};
```
Note that I only send advertisements on the VLAN3 network - I nominally don't want clients on the VLAN1 network to receive IPv6 addresses routed over the (slower) Xfinity network. 

A bit of extra spice here is the appearance of two `prefix` blocks in the advertisement.
The first `::/64` block will take the globally-routable IPv6 prefix of the `eth2.3` interface and broadcast it to clients, so that they can derive their own IPv6 global addresses.
The second prefix corresponds to the unique local address prefix I've chosen for this interface, where I assigned the RPi the address `fd02::3/64`.
Clients will _additionally_ assign themselves random addresses in this prefix, and can optionally be given static human-rememberable addresses in the same prefix, similar to how I assigned the RPi the address `fd02::3/64`. 
My logic here is that the final digit in the first octet should be the same as the third octet in the IPv4 address for the interface (`192.168.2.3`) and the last digit should match the final octet of the IPv4 address, to be easily remembered, and easily typed. 
This isn't quite how the `fd00::/8` address space is _supposed_ to be used, but I think I get to make my own rules, here. 

All this local addressing was done because the globally routable prefix _can change_ if the ISP decides to reorganize its address space, propagated down the line through router advertisements.
So to put truly static addresses anywhere, one needs to make use of the unique local address blocks.
This, for instance, allows the `RDDNS` block in the `radvd` config to advertise the unique local address of the RPi as the IPv6 addressable DNS server for the VLAN3 network. 

The final state of the IPv6 network for the RPi can be summarized by `ip -6 route`
```plaintext
2001:558:4042:22::/64 via fe80::201:5cff:fe78:dc46 dev eth1 proto ra metric 3 pref medium
2001:558:501c:5c::/64 via fe80::201:5cff:fe78:dc46 dev eth1 proto ra metric 3 pref medium
2001:558:6027:22::/64 via fe80::201:5cff:fe78:dc46 dev eth1 proto ra metric 3 pref medium
2001:558:802e:11d::/64 via fe80::201:5cff:fe78:dc46 dev eth1 proto ra metric 3 pref medium
[lan1_prefix]::/64 dev eth2.1 proto dhcp metric 1008 pref medium
[lan3_prefix]::/64 dev eth2.3 proto dhcp metric 1009 pref medium
fd01::/64 dev eth2.1 proto kernel metric 256 pref medium
fd02::/64 dev eth2.3 proto kernel metric 256 pref medium
fe80::/64 dev eth2 proto kernel metric 256 pref medium
fe80::/64 dev eth2.1 proto kernel metric 256 pref medium
fe80::/64 dev eth2.3 proto kernel metric 256 pref medium
fe80::/64 dev eth1 proto kernel metric 256 pref medium
default via fe80::201:5cff:fe78:dc46 dev eth1 proto ra metric 3 pref medium
```
where the routes on `eth1` come from DHCPv6 on the Xfinity network, and are a bit redundant, since the default route is on `eth1` to the same next-hop address.
I've replaced the actual prefixes for VLAN1 and VLAN2 with `[lan1_prefix]` and `[lan2_prefix]`.
The unique local address prefixes are routed over the appropriate interfaces, and the `fe80::/64` link-local prefixes go to all external interfaces.

Looking at `ip -6 addr` one can see the addresses bound to each interface.
```plaintext
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 state UNKNOWN qlen 1000
    inet6 ::1/128 scope host 
       valid_lft forever preferred_lft forever
3: eth1: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 state UP qlen 1000
    inet6 [eth1_global_ipv6]/128 scope global dynamic noprefixroute 
       valid_lft 341440sec preferred_lft 341440sec
    inet6 fe80::e3de:b1a:af62:d7ae/64 scope link 
       valid_lft forever preferred_lft forever
4: eth2: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 state UP qlen 1000
    inet6 fe80::7ec2:c6ff:fe10:bd35/64 scope link 
       valid_lft forever preferred_lft forever
8: eth2.1@eth2: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 state UP qlen 1000
    inet6 [lan1_prefix]::1/64 scope global dynamic noprefixroute 
       valid_lft 341440sec preferred_lft 341440sec
    inet6 fd01::3/64 scope global 
       valid_lft forever preferred_lft forever
    inet6 fe80::7ec2:c6ff:fe10:bd35/64 scope link 
       valid_lft forever preferred_lft forever
9: eth2.3@eth2: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 state UP qlen 1000
    inet6 [lan2_prefix]::1/64 scope global dynamic noprefixroute 
       valid_lft 341440sec preferred_lft 341440sec
    inet6 fd02::3/64 scope global 
       valid_lft forever preferred_lft forever
    inet6 fe80::7ec2:c6ff:fe10:bd35/64 scope link 
       valid_lft forever preferred_lft forever
```

### Actually routing packets to WAN

At this point, there is only a local network, using addresses that are not globally routable...
Actually, that's a lie, IPv6 is good to go: all devices can reach (and be reached, see next section) by any IPv6 device in the world.
IPv4, though, due to a much limited address pool of fewer than $2^{32}$ addresses, has forced everyone to create local networks using exclusively non-routable private addresses.
Here, I've used part of the `192.168.0.0/16` subnet, though there are other to choose from.
Routers upstream will simply refuse to forward packets with a destination or source in these subnets.
This means you're safe to assign these IPs locally, freely, and not worry that other people have reused the same `192.168.1.0/24` subnet elsewhere, but means you must employ some trickery to send to and receive from WAN.

That trickery is network address translation (NAT) where a router can rewrite the local source IP to its own global IP when sending, and rewrite the response's destination IP (its IP) to the original local IP by keeping track of which devices are using which port.
The beauty of NAT is that the ISP (Xfinity, and others, if you're lucky) can assign a single, global IPv4 to a household, and all devices can make use of it to receive messages.
The downside is that unsolicited inbound packets land on the NAT device, but cannot reach any of the local network devices without predetermined rules for which clients should receive packets on particular ports. 

NAT on Linux is handled by the `MASQUERADE` target of `iptables`, a program for modifying and filtering packets received by the machine.
There's no need to be too fancy here; I'll simply have all packets leaving `eth1` to the Xfinity WAN be NAT'd to the RPi's DHCP assigned WAN IP.
```bash
iptables -t nat -A POSTROUTING -o eth1 -j MASQUERADE
```

Some smaller ISPs [don't have enough IPv4 addresses to go around](https://en.wikipedia.org/wiki/IPv4_address_exhaustion), and may [NAT your router's IP address](https://en.wikipedia.org/wiki/Carrier-grade_NAT), making you unreachable from the rest of the world, which is why it's time to switch to IPv6!

### A bit of protection

It's critical to avoid being a nuisance and routing packets for just anyone.
With the configuration up to this point, anyone could set my RPi as their internet gateway, and the RPi would NAT for them, making traffic appear to come from me.
(Since the return path is not routed, this would serve no useful purpose, but could be used for abuse.)
It's also important to protect the local network from potential bad-actors, by not routing unwanted packets to the local network at all.
To lock this down, it's customary to have `iptables` drop any forwarding requests by default.
```bash
iptables -P FORWARD DROP
```
To make the router useful again, allow packets from the internal, trusted sources to be routed.
Here, I'll allow the VLAN1 network to use the RPi as a gateway, even though that isn't going to be a default route.
```bash
iptables -A FORWARD -s 192.168.1.0/24 -i eth2.1 -j ACCEPT
iptables -A FORWARD -s 192.168.2.0/24 -i eth2.3 -j ACCEPT
```
Finally, allow packets from anywhere to be routed if they are associated with a previously routed connection.
This takes care of NAT traffic inbound from WAN, though rules allowing packets to the internet subnets from `eth1` would be sufficient, since NAT traffic must already be associated with a previous connection.
```bash
iptables -A FORWARD -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
```
This last rule is a sufficient firewall for internal clients, but doesn't offer significantly more protection than NAT by itself.

A similar set of rules using `ip6tables` will lock down IPv6 routing, and provide firewall for the fully exposed IPv6 clients. 
Some people are uncomfortable with the lack of NAT "protection" in IPv6, but this is just as good.
```bash
ip6tables -P FORWARD DROP
ip6tables -A FORWARD -p ipv6-icmp -j ACCEPT
ip6tables -A FORWARD -i eth2.1 -j ACCEPT
ip6tables -A FORWARD -i eth2.3 -j ACCEPT
ip6tables -A FORWARD -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
```
One significant difference is that `ipv6-icmp` is allowed without restriction: this is required by IPv6 routing protocols.
A lesser difference is that, due to the potential dynamic nature of the IPv6 prefixes, no restriction of source address is made for packets incomming from the internal networks.

This configuration leaves the RPi itself fully exposed to the internet with no firewall, but protects internal clients. 
I'm perfectly fine with that, since I have been using the RPi as a DMZ host. 
Additional rules could be added to the `INPUT` chain to firewall the router.

To make these rules persistent across reboots, I used init scripts that use `ip{,6}tables-save` and `ip{,6}tables-restore` functionality to reload the rules at boot.

### Finishing touches

The RPi is now fully setup to route packets from VLAN3 to VLAN1 and to the Xfinity WAN, or to the gigabit fiber WAN, if it's from VLAN1's subnet. 
The last quality of life change is to allow packets on VLAN1 to be routed to VLAN3.
To accomplish this, I added a static route to the R6700 router via the Fresh Tomato GUI, but equivalent to the following:
```bash
ip route 192.168.2.0/24 via 192.168.1.3 dev vlan1
```
So any packets arriving at the R6700 will be routed to VLAN3 via the RPi, meaning I'll be able to communicate with any device on either network regardless of which I'm connected to.

## Happy streaming

Now, any devices on the VLAN3 network (that is, the virtual WAPs bridged to VLAN3) will receive DHCP announcements containing the RPi as the default route, which will forward packages to the Xfinity WAN.
All my streaming boxes are now connected to that network, and stream from the Xfinity network hapily, while my computers remain on the much faster symmetric gigabit fiber.
I even managed to setup IPv6 routing, and learn a bit more about it in the process.
All design goals accomplished, and I've finally found a use for my RPi!
The following diagram summarizes the network layout in my final home network.
{{< figure src="/images/home_network.png" class="center" >}}
