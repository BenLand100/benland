---
title: 'Using Hermes to automate POE control on TPLink switches'
date: '2026-09-29'
categories: 
  - Beekeeping
  - AI
  - Electronics
  - Programming
  - Sysadmin
description: A solution for powercycling the POE devices that sit outside and monitor my beehives, which should work for any TPLink POE switch, as designed by Hermes/AI because I never would have taken the time. 
slug: hermes-tplink-poe-power-cycle
toc: false
---

I have a [sensor platform monitoring my beehives](/post/2025/04/06/beelogger-beehive-sensors/) that occasionally gets impacted by inclement weather (or bees) in such a way that it stops responding to remote control commands.
Or, occasionally, one will experience a hardware fault (bees) that can't be corrected with software commands.
Nominally this is because one of the two ESP32 boards is hanging relatively exposed under the hive platform, susceptible to rain, while the other is much more enclosed. 
In other cases I've had I2C devices stop responding for unknown reasons (bees). 

Fortunately the low effort solution of turning the entire device off and on again (once dry) has worked every time. 
Unfortunately the solution is not so low effort, since the _JetStream 10-Port Gigabit Smart Switch with 8-Port PoE+_ (TL-SG2210P 5.0 on the 5.0.0 firmware build) I have powering these devices -- three Reolink cameras, two ESP32, and one exterior gigabit switch -- only really supports a web interface for remote command and control.
SSH exists as an option as well, and there is a documented command syntax for POE control once logged in --
```plaintext
enable
configure
interface range gigabitEthernet 1/0/5-7
power inline supply disable
end
configure
interface range gigabitEthernet 1/0/5-7
power inline supply enable
end
```
-- but good luck finding a modern SSH client that can connect to these switches! Even [Dropbear SSH](https://matt.ucc.asn.au/dropbear/dropbear.html) has dropped support for its protocols. 

Being stuck with the web UI generally that means the solution is some script that hits the endpoints on the webpage to achieve the result of clicking around, and while that is ultimately the case here, a prior inspection of the web UI's html source revealed good support for IE 8 but not a single rendered element.
The whole thing was generated with a big jQuery/AJAX library spanning dozens of minified Javascript source files.

I wrote that off as not worth my time. I have to power cycle these things maybe 10 times a year, concentrated in the warmer months, and digging through some Enterprise Quality(tm) Javascript just wasn't worth it in comparison.
Then modern AI came along, happily confirming there is really no good way to automate control of these POE switches, and ready to spend its time doing whatever I asked.
Google's Gemini Flash 3.8 and Antigravity had come up with the SSH approach above and said it was in theory possible to inspect the HTTP transaction of the web UI (as I already knew) but wouldn't just figure it out for me. 
So, I installed [Hermes Agent](https://hermes-agent.nousresearch.com/) in a cleanroom Docker container, hooked it up to [GPT-6 Luna via OpenRouter](https://openrouter.ai/openai/gpt-6-luna) and gave it a task:

> Using these credentials (username / password) connect to the web interface of hubswitch.home.arpa and figure out how to automate power cycling the POE ports 5, 6, 7.

Half an hour and $0.30 of Luna credits later, Hermes had created and tested, through inspection of the javascript and interrogation of the APIs, a working `poe_cycle.py` script:

```python
#!/usr/bin/env python3
"""
TP-Link TL-SG2210P v5.0 PoE Port Power Cycler

Automates PoE port control (power cycle, status query, turn off/on)
via the switch's native HTTP JSON API.
"""

import argparse
import json
import os
import sys
import time
import urllib.error
import urllib.request
from typing import Dict, List, Optional, Tuple

DEFAULT_HOST = os.environ.get("POE_SWITCH_HOST", "hubswitch.home.arpa")
DEFAULT_USER = os.environ.get("POE_SWITCH_USER", "username")
DEFAULT_PASS = os.environ.get("POE_SWITCH_PASS", "password")
DEFAULT_PORTS = [5, 6, 7]
DEFAULT_DELAY = 5.0

PORT_LABELS = {
    1: "Port 1",
    2: "Port 2",
    3: "Port 3",
    4: "Port 4",
    5: "Apiary camera",
    6: "Hive 1 camera",
    7: "Gigabit switch w/ Hive1 + Hive 2 sensors and Hive 2 camera",
    8: "Port 8",
}


class TL_SG2210P_Client:
    def __init__(self, host: str, user: str, password: str, timeout: float = 10.0):
        self.host = host.rstrip("/")
        if not self.host.startswith("http://") and not self.host.startswith("https://"):
            self.base_url = f"http://{self.host}"
        else:
            self.base_url = self.host
        self.user = user
        self.password = password
        self.timeout = timeout
        self.tid: Optional[str] = None
        self.usr_lvl: Optional[int] = None

    def _post(self, path: str, payload: dict, params: Optional[dict] = None) -> dict:
        url = f"{self.base_url}/{path.lstrip('/')}"
        if params:
            query = "&".join(f"{k}={v}" for k, v in params.items())
            url = f"{url}?{query}"

        data = json.dumps(payload).encode("utf-8")
        req = urllib.request.Request(
            url,
            data=data,
            headers={
                "Content-Type": "application/json",
                "User-Agent": "poe_cycler/1.0",
            },
        )
        with urllib.request.urlopen(req, timeout=self.timeout) as resp:
            body = resp.read().decode("utf-8")
            return json.loads(body)

    def login(self):
        """Authenticate with the switch and retrieve session token (_tid_) and user level."""
        res = self._post(
            "/data/login.json",
            {
                "username": self.user,
                "password": self.password,
                "operation": "write",
            },
        )
        if not res.get("success"):
            error_code = res.get("errorcode", "unknown")
            raise RuntimeError(f"Login failed (errorcode={error_code}): {res}")

        data = res.get("data", {})
        self.tid = data.get("_tid_")
        self.usr_lvl = data.get("usrLvl", 1)
        if not self.tid:
            raise RuntimeError(f"Login response missing _tid_: {res}")

    def logout(self):
        """Cleanly terminate the session on the switch."""
        if not self.tid:
            return
        try:
            self._post(
                "/data/logout.json",
                {"operation": "write"},
                params={"_tid_": self.tid, "usrLvl": self.usr_lvl},
            )
        except Exception as e:
            # Don't throw during logout cleanup
            pass
        finally:
            self.tid = None
            self.usr_lvl = None

    def __enter__(self):
        self.login()
        return self

    def __exit__(self, exc_type, exc_val, exc_tb):
        self.logout()

    def get_poe_status(self) -> List[dict]:
        """Fetch current PoE configuration and runtime status for all ports."""
        if not self.tid:
            raise RuntimeError("Not authenticated")

        res = self._post(
            "/data/poeCfgGrid.json",
            {"operation": "load"},
            params={"_tid_": self.tid, "usrLvl": self.usr_lvl},
        )
        if not res.get("success"):
            raise RuntimeError(f"Failed to fetch PoE status: {res}")
        return res.get("data", [])

    def set_poe_state(self, port_states: Dict[int, bool]):
        """
        Enable or disable PoE on one or more ports simultaneously.
        port_states: {port_num: True for ON, False for OFF}
        """
        if not self.tid:
            raise RuntimeError("Not authenticated")

        updates = []
        for port, enabled in port_states.items():
            updates.append({
                "key": str(port),
                "poeStatus": 1 if enabled else 0,
            })

        res = self._post(
            "/data/poeCfgGrid.json",
            {
                "operation": "update",
                "new": updates,
            },
            params={"_tid_": self.tid, "usrLvl": self.usr_lvl},
        )
        if not res.get("success"):
            raise RuntimeError(f"Failed to update PoE states for ports {list(port_states.keys())}: {res}")
        return res


def print_ports_status(ports_data: List[dict], highlight_ports: Optional[List[int]] = None):
    print(f"{'Port':<6} {'Name / Description':<35} {'PoE Admin':<11} {'Power Status':<14} {'Power (W)':<10} {'Current (mA)':<13} {'Voltage (V)':<11}")
    print("-" * 105)
    for p in ports_data:
        port_num = int(p.get("port", p.get("key", 0)))
        if highlight_ports and port_num not in highlight_ports:
            continue
        label = PORT_LABELS.get(port_num, f"Port {port_num}")
        admin_status = "ENABLED" if p.get("poeStatus") == 1 else "DISABLED"
        pwr_code = p.get("powerStatus", 0)
        # 0 = Off, 1 = Turning on / searching, 2 = Delivering power, etc.
        pwr_status = "Delivering" if pwr_code == 2 else ("Off" if pwr_code == 0 else f"Code {pwr_code}")
        power_w = f"{p.get('power', 0):.1f} W"
        current_ma = f"{p.get('current', 0)} mA"
        voltage_v = f"{p.get('voltage', 0):.1f} V"

        marker = "*" if highlight_ports and port_num in highlight_ports else " "
        print(f"{marker}{port_num:<5} {label:<35} {admin_status:<11} {pwr_status:<14} {power_w:<10} {current_ma:<13} {voltage_v:<11}")


def parse_ports(port_arg: str) -> List[int]:
    ports = []
    for part in port_arg.split(","):
        part = part.strip()
        if not part:
            continue
        if "-" in part:
            start, end = part.split("-", 1)
            ports.extend(range(int(start), int(end) + 1))
        else:
            ports.append(int(part))
    return sorted(list(set(ports)))


def main():
    parser = argparse.ArgumentParser(
        description="Power cycle or control PoE ports on TP-Link TL-SG2210P v5.0 switch."
    )
    parser.add_argument(
        "--host",
        default=DEFAULT_HOST,
        help=f"Switch hostname or IP (default: {DEFAULT_HOST})",
    )
    parser.add_argument(
        "-u",
        "--username",
        default=DEFAULT_USER,
        help=f"Admin username (default: {DEFAULT_USER})",
    )
    parser.add_argument(
        "-p",
        "--password",
        default=DEFAULT_PASS,
        help="Admin password",
    )
    parser.add_argument(
        "--ports",
        default="5,6,7",
        help="Comma-separated port numbers or ranges to operate on (default: 5,6,7)",
    )
    parser.add_argument(
        "--delay",
        type=float,
        default=DEFAULT_DELAY,
        help=f"Seconds to wait between turning off and turning on (default: {DEFAULT_DELAY})",
    )
    parser.add_argument(
        "--action",
        choices=["cycle", "status", "off", "on"],
        default="cycle",
        help="Action to perform: cycle (off -> wait -> on), status, off, on (default: cycle)",
    )

    args = parser.parse_args()
    target_ports = parse_ports(args.ports)

    print(f"Connecting to switch at {args.host}...")
    try:
        with TL_SG2210P_Client(args.host, args.username, args.password) as client:
            print("Authenticated successfully.")

            if args.action == "status":
                status = client.get_poe_status()
                print("\nCurrent PoE Status:")
                print_ports_status(status)
                return

            if args.action == "off":
                print(f"\nTurning OFF PoE on ports: {target_ports}")
                for port in target_ports:
                    print(f"  - Port {port}: {PORT_LABELS.get(port, 'Unknown')}")
                client.set_poe_state({p: False for p in target_ports})
                print("PoE turned OFF.")
                return

            if args.action == "on":
                print(f"\nTurning ON PoE on ports: {target_ports}")
                for port in target_ports:
                    print(f"  - Port {port}: {PORT_LABELS.get(port, 'Unknown')}")
                client.set_poe_state({p: True for p in target_ports})
                print("PoE turned ON.")
                return

            # Action: cycle
            print(f"\n=== Power Cycling Ports: {target_ports} ===")
            for port in target_ports:
                print(f"  - Port {port}: {PORT_LABELS.get(port, 'Unknown')}")

            # 1. Show initial status
            print("\nInitial Port Status:")
            status = client.get_poe_status()
            print_ports_status(status, highlight_ports=target_ports)

            # 2. Turn off
            print(f"\n[1/3] Disabling PoE power on ports {target_ports}...")
            client.set_poe_state({p: False for p in target_ports})
            print("      PoE power disabled.")

            # 3. Wait
            print(f"\n[2/3] Waiting {args.delay:.1f} seconds for capacitors to discharge and sensors to reset...")
            time.sleep(args.delay)

            # 4. Turn on
            print(f"\n[3/3] Re-enabling PoE power on ports {target_ports}...")
            client.set_poe_state({p: True for p in target_ports})
            print("      PoE power re-enabled.")

            # 5. Wait for PoE negotiation and show final status
            print("\nWaiting for PoE link negotiation (4s)...")
            time.sleep(4.0)
            print("\nFinal Port Status:")
            status = client.get_poe_status()
            print_ports_status(status, highlight_ports=target_ports)
            print("\nPower cycle completed successfully.")

    except Exception as e:
        print(f"\nError: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
```

This reveals a rather opaque scheme of POSTs to JSON suffixed files with session data encoded as URL parameters and JSON encoded data payloads as the underlying control mechanism.
Syntax would have been inferred from observing what the Javascript did in response to event handlers -- exactly the kind of thing I could do but never would have taken the time to. 
It even has a nice set of parameters with defaults set to exactly what I asked for. 

Overall, I was decently impressed with how Hermes+Luna approached the problem, though the steps were unsurprising.
Hermes provides complete control over a computer (hence my Docker cleanroom) to any tool-calling LLM (GPT-6 Luna here, but I've also tested Qwen-3.5-9b on my RTX3090) along with a huge body of builtin skills for multi-step problem solving, delegation to sub-agents, context management, and recursive improvement by writing new skills and incorporating new tools.
Any good LLM, even a low-powered one like Luna - chosen purely for being the lowest cost "big name" LLM available, will suffice here as long as it has a big context window (64k context for Qwen was not enough, 128k would have worked).
The Hermes harness is more than capable of letting the LLM look up information it does not know, pivoting to different approaches if something fails, and autonomously deciding when this should be done. 

With all that in mind, Hermes+Luna first curl'd the landing page, decided (as did I) Javascript hell was too much for terminal commands, and started inspecting the source as linked in the landing page (as I was unwilling to do).
This allowed it to mock up a Python-based login function, following redirects that revealed even more Javascript.
Some tactical exploration found the PoE config page logic, and the procedure for getting and setting the POE status, which was easy enough to translate to Python.
It then tested its interface a few times, trying out the different parameters to make sure it all worked (which I would skip), and even writing a README.md (I didn't even bother to include it here, if that signals the likelihood I would have written one) for good measure.

Not once did Hermes+Luna complain the Javascript was minified, nor did it ever need to look at a rendered webpage or even execute the Javascript it inspected, despite all this being within its capabilities. That's when I realized humans were toast. 
