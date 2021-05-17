# Setup LoRaWAN - TheThingsStack
Link: https://thethingsstack.io/v3.7.0-rc1/guides/getting-started/

**Note**: For Linux machines only, as for windows it creates certificate directories instead of files and the stack won't run.

# Installing on the Edge (private address/IP)
This option uses Self-Signed certificats.

In `Clearlinux` the `/etc/hosts` file might be missing so must create one:
```sh
sudo -i
cat << 'EOF' > /etc/hosts
127.0.0.1   localhost localhost.localdomain localhost4 localhost4.localdomain4
::1         localhost localhost.localdomain localhost6 localhost6.localdomain6
EOF
```
ipv4 forwards enable (this is already done if you have kubernetes installed):
```sh
sudo mkdir -p /etc/sysctl.d/

cat <<EOT | sudo bash -c "cat > /etc/sysctl.d/60-k8s.conf"
net.ipv4.ip_forward=1
net.ipv4.conf.default.rp_filter=1
net.ipv4.conf.all.rp_filter=1
EOT

sudo systemctl restart systemd-sysctl
```

## Firewall
`sudo swupd bundle-add firewalld`

Port settings

```sh
sudo firewall-cmd --zone=public --add-port=1885/tcp --permanent
sudo firewall-cmd --zone=public --add-port=1700/udp --permanent
sudo firewall-cmd --reload
```



# Installing on Cloud (with public address)
This option uses Let's Encrypt Certificates.

```sh
#!/bin/sh
docker-compose pull
docker-compose run --rm stack is-db init
docker-compose run --rm stack is-db create-admin-user --id admin --email jerry3k@hotmail.com
docker-compose run --rm stack is-db create-oauth-client --id cli --name "Command Line Interface" --owner admin --no-secret --redirect-uri "local-callback" --redirect-uri "code"
docker-compose run --rm stack is-db create-oauth-client --id console --name "Console" --owner admin --secret console --redirect-uri "https://localhost/console/oauth/callback" --redirect-uri "/console/oauth/callback"
docker-compose up
```

To remove stack
```sh
docker-compose down
```
# LoRaWAN Appendix

## Uplink and Downlink messages
LoRaWAN supports both `uplink` as `downlink` messaging; messages from end-device to the network are called `uplink` and network to end-device messages are called `downlink`. The most common way to use LoRaWAN is to use the uplink so a sensor can report any value to the `Application Server`. Under certain conditions it might be useful to use a downlink message to provide the sensor with an acknowledgment to make clear that the message has arrived in the network and will be forwarded to the `Application Server`.

Downlink messages can also be used to control settings of the sensor, for instance to adjust its update frequency or any other settings on the appliance. Another application of downlink messages could be to control an actuator like a valve or a lock. If you are sending downlinks (from the Application Server to the end-device) these are in theory unconfirmed messages. Although there is a message log in the Wireless Logger the information reported gives no indication whether the device received it as it could have gone lost on the radio path. To make sure that this downlink has arrived an acknowledgment can be sent via the uplink, so the Application Server gets notified that the sensor has received its new settings. The downlink message queue acts on a First In, First Out mechanism, which means in a full queue (5 messages) the oldest message is removed when a new one is queued. The queue cannot be changed or inspected by the customer.

## The `868` MHz band and the Duty cycle
The maximum number of messages per day is related to the fact that KPN operates the LoRa network in the unlicensed 868 MHz ISM band. The number of messages is limited due to the duty cycle and payload in combination with the quality offered by the network. The 868 MHz ISM band limits the use of a device to 1% of the time on air. LoRaWAN specifies that each time a message is send in one ISM subband, the device must wait the remaining time of the duty cycle in that band before resending. This means that a sensor sending a message which takes 1 second should be quiet for 99 seconds after that. The time on air itself is related to the message size and the distance to the gateway.

The closer the end-device is to the gateway the higher the data rate (and the lower the Spreading Factor used in the LoRa modulation). While being very close to the gateway the time on air will be minimum (low modulation overhead) and maximum payload can be used, so more messages per day can be supported.

## Downlink capacity
Because downlink capacity is shared across all talking end-devices this is more limited than upload messaging; gateways are also seen as one device, so duty cycle applies to the gateways as well. For receiving uplink messages from devices, no regulatory limit applies, but for downlink messages the gateway has to obey the Duty Cycle. Downlink capacity is increased by sending on a low SF, changing sub-bands and setting up gateways in area’s with many LoRa Devices. Nevertheless, the downlink capacity stays limited. Developers should design their solution with a minimum number of downlink messages. LoRa Acknowledgements are also downlink messages. 

# Activation of Devices
LoRaWANallows  for  its  packets  to  be  both  signed  and  encrypted  by  the  use  of  keys  known  to  both  the  node (module/sensor) and the LoRaWAN network/application server. The following are the keys:
1. Network Session Key (NwkSKey)
2. Application Session Key (AppSKey)In addition,each device on the network has a unique device address (DevAddr).These keys are known only to the individual node  and the network/applicationserver. This means that another node or man-in-the-middle is notable to decode the packetpayload.

The following twomethods are used to deploy these keys:
1. Over-the-Air Activation (OTAA)
2. Activation by personalization (ABP)

With either of these  methods, thesame  keys are  loaded into both the module andnetwork  server that allows end-to-end data security.
### **Over-the-air-activation (OTAA)**
Over-the-Air  activation  (OTAA)  uses  an  application  ID  (AppEUI)  and  an  application  key  (AppKey)  along  with  a device ID (DevEui) to derivethe network session key (NwkSKey), application session key (AppSKey)and the device address. A  device  address  (DevAddr) isassigned  by  the  network.  OTAA  is  the  preferred  methodbecauseof  its security advantages including regeneration of the session keys and simplifying network management.

![](literature/LoRa_OTAA.png)

**Keys needed and their explainations for OTAA**

1. The `DevEUI` is an ID in the IEEE EUI64 address space used to identify a device. It is supplied by the device manufacturer. A deprecated algorithm exists to convert 48bit MAC addresses to EUI64. For MAC addresses with 6 bytes (e.g. 01 02 03 04 05 06) put ff fe or ff fe in the middle (e.g. 01 02 03 ff fe 04 05 06). This algorithm has been deprecated as it may lead to collisions with other DevEUIs. During over the air activation a DevAddr is assigned to the device. This DevAddr is used in the LoRaWAN protocol afterwards. The DevEUI is sent unencrypted.    
    > The user can derive their own DevEUI

2. The `JoinEUI` (formerly called `AppEUI`) is a global application ID in the IEEE EUI64 address space identifying the join server during the over the air activation. The AppKey is an AES128 root key specific to the end device. Whenever an end device joins a network via over the air activation(OAT), the AppKey is used to derive the session keys NwkSKey and AppSKey specific for that end device to encrypt and verify network communication and application data. The AppEUI is stored in the end-device before the activation procedure is executed.

    > The `AppEUI` can be `different` for each device or it can also be same for all device. It also depends on what kind of application server you are using.
    
    > For example in Chirpstack or TheThingsIndustries (TTI or TTS) you can have unique AppKey,`AppEUI` and DevEUI but in TheThingsNetwork (TTN you can register many devices for one application or AppEUI. But note that AppKey and DevEUI should always be unique for each end node.
    

3. `AppKey` is the encryption key used for messages during every over the air activation. After the activation the AppSKey is used. A listener knowing the AppKey can derive the AppSKey. So you want to keep the AppKey secret. Which side of the communication channel creates it is not important. You simply want to be sure that it is random. Whenever an end device joins a network via over the air activation (OAT), the AppKey is used to derive the session keys NwkSKey and AppSKey specific for that end device to encrypt and verify network communication and application data.
    > The AppKey should be `unique` for each device. The user can derive their own AppKey, this is also stored in the device.


Learn more here: https://www.centennialsoftwaresolutions.com/post/deveui-appeui-joineui-and-appkey



# The Things Stack (TTI or TTS)
## MQTT Uplink messages
Ref Link: https://thethingsstack.io/v3.7.0/reference/application-server-data/mqtt/

### Subscribing to Upstream Traffic
While you could subscribe to separate topics, for the tutorial subscribe to `#` to subscribe to all messages. I would stongly suggest to start from there by using `#`.

The Application Server publishes on the following topics:
```
v3/{application id}@{tennant id}/devices/{device id}/join
v3/{application id}@{tennant id}/devices/{device id}/up
v3/{application id}@{tennant id}/devices/{device id}/down/queued
v3/{application id}@{tennant id}/devices/{device id}/down/sent
v3/{application id}@{tennant id}/devices/{device id}/down/ack
v3/{application id}@{tennant id}/devices/{device id}/down/nack
v3/{application id}@{tennant id}/devices/{device id}/down/failed
```


With your MQTT client subscribed, when a device joins the network, a join message gets published. For example, for a device ID dev1, the message will be published on the topic v3/app1/devices/dev1/join.
Show example
```json 
{ "end_device_ids": { "device_id": "dev1", "application_ids": { "application_id": "app1" }, "dev_eui": "4200000000000000", "join_eui": "4200000000000000", "dev_addr": "01DA1F15" }, "correlation_ids": [ "gs:conn:01D2CSNX7FJVKQPCVG612QF1TX", "gs:uplink:01D2CT834K2YD17ZWZ6357HC0Z", "ns:uplink:01D2CT834KNYD7BT2NHK5R1WVA", "rpc:/ttn.lorawan.v3.GsNs/HandleUplink:01D2CT834KJ4AVSD1SJ637NAV6", "as:up:01D2CT83AXQFQYQ35SR74CTWKH" ], "join_accept": { "session_key_id": "AWiZpAyXrAfEkUNkBljRoA==" } } 
```

You can use the correlation IDs to follow messages as they pass through The Things Stack.

When the device sends an uplink message, a message will be published to the topic v3/{application id}/devices/{device id}/up.
```json 
{ "end_device_ids": { "device_id": "dev1", "application_ids": { "application_id": "app1" }, "dev_eui": "4200000000000000", "join_eui": "4200000000000000", "dev_addr": "01DA1F15" }, "correlation_ids": [ "gs:conn:01D2CSNX7FJVKQPCVG612QF1TX", "gs:uplink:01D2CV8HF62ME0D7MZWE38HHH8", "ns:uplink:01D2CV8HF6FYJHKZ45YY1DB3MR", "rpc:/ttn.lorawan.v3.GsNs/HandleUplink:01D2CV8HF6XR7ZFVK768PDG3J4", "as:up:01D2CV8HNGJ57G25BW0FCZNY07" ], "uplink_message": { "session_key_id": "AWiZpAyXrAfEkUNkBljRoA==", "f_port": 15, "frm_payload": "VGVtcGVyYXR1cmUgPSAwLjA=", "rx_metadata": [{ "gateway_ids": { "gateway_id": "eui-0242020000247803", "eui": "0242020000247803" }, "time": "2019-01-29T13:02:34.981Z", "timestamp": 1283325000, "rssi": -35, "snr": 5, "uplink_token": "CiIKIAoUZXVpLTAyNDIwMjAwMDAyNDc4MDMSCAJCAgAAJHgDEMj49+ME" }], "settings": { "data_rate": { "lora": { "bandwidth": 125000, "spreading_factor": 7 } }, "data_rate_index": 5, "coding_rate": "4/6", "frequency": "868500000", "gateway_channel_index": 2, "device_channel_index": 2 } } } 
``` 
`Elsys` Devide after payload decoded example:
```json
{"end_device_ids":{"device_id":"elsys5k-1","application_ids":{"application_id":"london-02"},"dev_eui":"A81758FFFE040686","join_eui":"70B3D57ED002D32F","dev_addr":"270000D8"},"correlation_ids":["as:up:01E507FV17GEEY1VD7HKK0VHE1","gs:conn:01E5041TVSCX263W1YC9WAWKAS","gs:uplink:01E507FTTPSM0CYND6A46PXKHG","ns:uplink:01E507FTTQ3PPRF42TP09N1PAF","rpc:/ttn.lorawan.v3.GsNs/HandleUplink:01E507FTTQR8HNP9CN1A48EXF6"],"received_at":"2020-04-03T14:35:33.287875110Z","uplink_message":{"session_key_id":"AXFAc0M4TdHyn4bRdzsfOA==","f_port":5,"f_cnt":3,"frm_payload":"AQEyAiAD/flABAPXBw3eDwA=","decoded_payload":{"accMotion":0,"humidity":32,"light":983,"temperature":30.6,"vdd":3550,"x":-3,"y":-7,"z":64},"rx_metadata":[{"gateway_ids":{"gateway_id":"rak-7243","eui":"B827EBFFFE32BBBE"},"timestamp":3607096676,"rssi":-55,"channel_rssi":-55,"snr":6.5,"uplink_token":"ChYKFAoIcmFrLTcyNDMSCLgn6//+Mru+EOTa/7cN","channel_index":5}],"settings":{"data_rate":{"lora":{"bandwidth":125000,"spreading_factor":7}},"data_rate_index":5,"coding_rate":"4/5","frequency":"867500000","timestamp":3607096676},"received_at":"2020-04-03T14:35:33.079982276Z"}}
```

# Helping Tools
TTN address: `router.eu.thethings.network`

# Frequency Plans
Settings for Gateway, especially Dragino

* Link: https://www.thethingsnetwork.org/docs/lorawan/frequency-plans.html
* Link: https://github.com/TheThingsNetwork/gateway-conf/blob/master/EU-global_conf.json
* Fundamentals: https://www.thethingsnetwork.org/docs/lorawan/modulation-data-rate.html
* Airtime Calculator: https://www.thethingsnetwork.org/airtime-calculator
* 

## VNC Server
### Clearlinux

```sh
sudo swupd bundle-add vnc-server
vncserver # follow instructions (IP-Address:5901)
```
