---
title: Prioritize network traffic by IP in Linux
date: '2020-12-28'
categories:
  - Sysadmin
slug: network-traffic-priority
---

I have a server on a residental internet connection with relatively limited upload bandwidth.
That server hosts this website along with several services for personal use including:
* A [Jellyfin](https://jellyfin.org/) media server for streaming my own video content
* A [Booksonic-Air](https://github.com/popeen/Booksonic-Air) audiobook streaming server
* Automated full-system backups using [rclone](https://rclone.org/) to Google Drive with [borgbackup](https://www.borgbackup.org/)

If I'm listening to an audio book or streaming some other media to myself, I certainly don't want to buffer if someone else wants to download a large file or its time to ship regularly scheduled backups off to the Google Panopticon (encrypted, of course).
Fortunately, there is built-in functionality in Linux that allows upload packets to be prioritized and reserve some fraction of the available bandwidth.
This functionality can also limit the total upload rate from a particular linux machine such that there is always bandwidth left over for other machines on the same network.
Much more complicated behavior is possible, but I decided to stick with something simple for now.

## Traffic shaping
A machine only has control over the packets it transmits. I.E. there is no shaping of _incomming_ traffic, but _outgoing_ traffic can be controlled as finely as you're willing to specify rules.
The [TrafficControl (`tc`) utility](https://man7.org/linux/man-pages/man8/tc.8.html) is the standard tool for modifying these rules, and it has absolutely bonkers syntax.
Each network adapter on a Linux machine can have a "queuing discipline" assigned to it that orders outgoing packets for transmission at the kernel level.
By default this is always set to a first-in-first-out queue (`pfifo_fast`) that takes no configuration, and simple options like a stochastic fairness queuing (`SFQ`) exist to equally share bandwidth between all outgoing connections.

For more fine-grained control, queuing disciplines like hierarchy token bucket (`HTB`) exist to assign outgoing packets to several different classes, with each class having rules for minimum guaranteed bandwidth, maximum potential bandwidth, and in what order spare bandwidth is allocated.
This is precisely what I want to do.
The one caveat that I couldn't find a well documented solution for is how to prioritize packets to a particular outbound IP (the IP I stream to), so this post documents the solution I ended up with in case it is useful to others.
In short, after setting up an `HTB` queuing discipline with appropriate rules, the most straightforward solution I arrived at was to mark packets with `iptables` rules and have those packets be assigned to a particular `HTB` class, while all other packets go to a default `HTB` class.

## `HTB` classes

In this section assume I have one network adapter named `eth1` for which I want a maximum of 11mbit(/s) upload bandwidth.
The following will create a `HTB` queue discipline on `eth1` named `1:`:
```bash
tc qdisc add dev eth1 root handle 1: htb default 20
```
It is unclear to me why the name `1:` is used here, but perhaps someone willing to read more of the (complicated) `tc` documentation will understand.
Conceptually, this is the "root" of a tree-like structure below which `HTB` classes will be defined.
Importantly, this specifies that some leaf of this tree structure with the name `1:20` (`1:` + `20` evidently) will be the default class for unclassified packets.

The next step is to define the "child class" of this `HTB` "root" that allocates a certain amount of bandwidth (11mbit) on the interface:
```bash
tc class add dev eth1 parent 1: classid 1:1 htb rate 11mbit burst 15k
```
Note this class is named `1:1` with the parent `1:` created in the previous command.
Here, `burst` refers to the amount of data transmitted before potentially switching to a different class. 
If it is too small, there will be a lot of overhead in the traffic shaping logic, and bandwidth will suffer. If it is too large, traffic shaping will be discontinuous, and latency may be erratic. It should be as large as the largest child burst.

I'll allocate minimum 8mbit bandwidth to my prioritized traffic (plenty for a 720p HD video stream), which can potentially use up to 11mbit (all) available bandwidth.
```bash
tc class add dev eth1 parent 1:1 classid 1:10 htb rate 8mbit ceil 11mbit burst 15k prio 0
```
The `prio 0` part signifies this (lower is first) rule will receive additional bandwidth, up to its ceiling, before other rules (with larger `prio`). 


I'll allocate the other 3mbit bandwidth as the minimum for all other traffic, potentially using up to 10mbit to never max out the available upload bandwidth.
```bash
tc class add dev eth1 parent 1:1 classid 1:20 htb rate 3mbit ceil 10mbit burst 15k prio 1
```
Note the class is named `1:20`, which was the default given in the queue discipline.

The final step is a quality-of-life addition and likely not strictly required, but after packets are assigned to `HTB` classes, the default is simply another first-in-first-out queue.
To make this a bit more balanced, a simple `SFQ` fairshare queue is added as a leaf to each class.
```bash
tc qdisc add dev eth1 parent 1:10 handle 10: sfq perturb 10
tc qdisc add dev eth1 parent 1:20 handle 20: sfq perturb 10
```
The `perturb` option relates to how frequently the fairshare parameters are recalculated. Like the `burst` arguments, this should be big enough but not too big. 

Now, by default, all outgoing packets on the `eth1` interface will be assigned to `1:20` with the bandwidth rules it implies.
To assign packets to other rules, `tc` includes an overly-complex filter syntax that I simply can't be bothered to learn for a one-off solution like this.
Fortunately, the filter syntax can detect packets marked by `iptables` rules we'll setup in the next section.
This command will assign packets marked `0x1` (`handle 1`) to the higher-bandwidth `1:10` class:
```bash
tc filter add dev eth1 parent 1:0 protocol ip prio 1 handle 1 fw classid 1:10
```
I will take no questions on this `filter` syntax!

## Marking packets with `iptables`

The last step in this endeavor is to mark outgoing packets on `eth1` with `0x1` if they should go to the high bandwidth class.
This can be done with `mangle` table rules, and should be applied to any packets traversing the `FORWARD` chain (if you are running a router or have packets coming from a sandboxed Docker instance) or `OUTPUT` chain (for packets originating from a local process).
The most straightforward way to accomplish this seems to be to create a new chain `QOS` that all outbound packets on `eth1` going through `FORWARD` and `OUTPUT` are sent to.
```bash
iptables -t mangle -N QOS
iptables -t mangle -A FORWARD -o eth1 -j QOS
iptables -t mangle -A OUTPUT -o eth1 -j QOS
```
Then packets matching any standard `iptables` rule can be marked with `0x1`. 
Here, I mark packets going to `${DEST_IP}` such that these packets get guaranteed higher bandwidth.
```bash
iptables -t mangle -A QOS -d ${DEST_IP} -j MARK --set-mark 0x1
```
No more buffering for me!

