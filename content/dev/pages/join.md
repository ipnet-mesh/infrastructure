---
title: Join
slug: join
menu_order: 10
---

# Getting Started with MeshCore

MeshCore is an open-source off-grid LoRa mesh networking platform. This guide will help you get connected to the network.

For detailed documentation, see the [MeshCore FAQ](https://github.com/meshcore-dev/MeshCore/blob/main/docs/faq.md).

## Node Types

MeshCore devices operate in different modes:

| Mode            | Description                                                                                        |
| --------------- | -------------------------------------------------------------------------------------------------- |
| **Companion**   | Connects to your phone via Bluetooth. Use this for messaging and interacting with the network.     |
| **Repeater**    | Standalone node that extends network coverage. Place these in elevated locations for best results. |
| **Room Server** | Hosts chat rooms that persist messages for offline users.                                          |

Most users start with a **Companion** node paired to their phone.

## Frequency Regulations

MeshCore uses LoRa radio, which operates on unlicensed ISM bands. You **must** use the correct frequency for your region:

| Region         | Frequency | Notes      |
| -------------- | --------- | ---------- |
| Europe (EU)    | 868 MHz   | EU868 band |
| United Kingdom | 868 MHz   | Same as EU |
| North America  | 915 MHz   | US915 band |
| Australia      | 915 MHz   | AU915 band |

Using the wrong frequency is illegal and may cause interference. Check your local regulations.

## Compatible Hardware

MeshCore runs on inexpensive low-power LoRa devices. Popular options include:

### Recommended Devices

| Device                                                                                          | Manufacturer | Features                             |
| ----------------------------------------------------------------------------------------------- | ------------ | ------------------------------------ |
| [Heltec V3](https://heltec.org/project/wifi-lora-32-v3/)                                        | Heltec       | Budget-friendly, OLED display        |
| [T114](https://heltec.org/project/mesh-node-t114/)                                              | Heltec       | Compact, GPS, colour display         |
| [T1000-E](https://www.seeedstudio.com/SenseCAP-Card-Tracker-T1000-E-for-Meshtastic-p-5913.html) | Seeed Studio | Credit-card sized, GPS, weatherproof |
| [T-Deck Plus](https://www.lilygo.cc/products/t-deck-plus)                                       | LilyGO       | Built-in keyboard, touchscreen, GPS  |

Ensure you purchase the correct frequency variant (868MHz for EU/UK, 915MHz for US/AU).

### Where to Buy

- **Heltec**: [Official Store](https://heltec.org/) or AliExpress
- **LilyGO**: [Official Store](https://lilygo.cc/) or AliExpress
- **Seeed Studio**: [Official Store](https://www.seeedstudio.com/)
- **Amazon**: Search for device name + "LoRa 868" (or 915 for US)

## Mobile Apps

Connect to your Companion node using the official MeshCore apps:

| Platform | App      | Link                                                                                         |
| -------- | -------- | -------------------------------------------------------------------------------------------- |
| Android  | MeshCore | [Google Play](https://play.google.com/store/apps/details?id=com.liamcottle.meshcore.android) |
| iOS      | MeshCore | [App Store](https://apps.apple.com/us/app/meshcore/id6742354151)                             |

The app connects via Bluetooth to your Companion node, allowing you to send messages, view the network, and configure your device.

## Flashing Firmware

1. Use the [MeshCore Web Flasher](https://flasher.meshcore.io/) for easy browser-based flashing
2. Select your device type and region (frequency)
3. Connect via USB and flash

## Next Steps

Once your device is flashed and paired:

1. Open the MeshCore app on your phone
2. Enable Bluetooth and pair with your device
3. Set your node name in the app settings
4. Configure your radio settings/profile for your region
5. You should start seeing other nodes on the network

## Companion Configuration

### Regions

It is possible to configure the regional scope for individual channels on your companion node. Configuration is done on a per-channel basis.

We recommend setting region scope on any public/general channels (e.g. Public, Test, Jokes etc) to `gb` (UK wide). Any local regional channels (e.g. `#eastofengland`, `#gb-est`) should be scoped with the appropriate regional scope, e.g. `gb-est` (East of England).

The default region scope (located in Experimental settings) should be left unset/empty.

## Contributing as a Remote Observer

You can contribute to IPNet by running a [LetsMesh Observer](https://github.com/agessaman/meshcore-packet-capture) — a lightweight Docker container that captures MeshCore RF traffic from a connected LoRa device and publishes decoded packets to IPNet's MQTT broker. Deploying observers throughout the region ensures MeshCore events (advertisements, messages, and nodes) are captured and not missed, feeding our network map, dashboard, and message history.

You can also optionally contribute to [LetsMesh Analyzer](https://letsmesh.com/) and [MeshRank.net](https://meshrank.net/become-an-observer).

### Prerequisites

- A compatible LoRa device (e.g. Heltec V3, T-Beam) connected via USB
- [Docker](https://docs.docker.com/get-docker/) and Docker Compose

### Setup

Download the Docker Compose files:

```bash
mkdir meshcore-observer && cd meshcore-observer

wget https://raw.githubusercontent.com/ipnet-mesh/meshcore-hub/main/contrib/packetcapture/docker-compose.yml
wget https://raw.githubusercontent.com/ipnet-mesh/meshcore-hub/main/contrib/packetcapture/.env.example

cp .env.example .env
```

Edit `.env` with the following values:

| Variable              | Value          | Description                                                                      |
| --------------------- | -------------- | -------------------------------------------------------------------------------- |
| `SERIAL_PORT`         | `/dev/ttyUSB0` | Device path for your LoRa device. Use `/dev/serial/by-id/...` for a stable path. |
| `IATA`                | e.g. `STN`     | 3-letter airport code for your location                                          |
| `ORIGIN`              | `observer`     | Observer identifier (or choose a unique name)                                    |
| `IPNET_ENABLE`        | `true`         | Contribute to IPNet MeshCore Hub MQTT broker                                     |
| `LETSMESH_ENABLE`     | `false`        | Contribute to LetsMesh Analyzer                                                  |
| `LETSMESH_REGION`     | `eu`           | LetsMesh MQTT Region (`eu`/`us`)                                                 |
| `MESHRANK_ENABLE`     | `false`        | Contribute to MeshRank.net MQTT broker                                           |
| `MESHRANK_UPLINK_KEY` | `A1B2C3D4...`  | MeshRank.net MQTT credentials (https://meshrank.net/become-an-observer)          |

- For LetsMesh Analyzer, enable `LETSMESH_ENABLE` and configure the `LETSMESH_REGION` variable to either `eu` or `us` region.
- For MeshRank.net, register an account, enable `MESHRANK_ENABLE` and set `MESHRANK_UPLINK_KEY` to your generated MQTT credential.

Start the observer:

```bash
docker compose up -d
```

Check that it's running:

```bash
docker compose logs -f
```

You should see log output confirming a successful MQTT connection to `mqtt.ipnt.uk` and packets being published as MeshCore traffic is received over LoRa.
