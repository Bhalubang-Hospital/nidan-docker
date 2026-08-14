# OpenELIS Analyzer Bridge (Sysmex XN-350)

Middleware that receives ASTM from instruments and forwards to OpenELIS.

```
Sysmex XN-350  --ASTM TCP-->  Analyzer Bridge  --HTTP-->  OpenELIS + SysmexXN-L plugin
```

## Plugin JAR

```bash
cd ../openelisglobal-plugins
mvn clean package -pl :SysmexXNLAnalyzer -am -DskipTests
cp analyzers/SysmexXN-L/target/SysmexXNLAnalyzer-*.jar \
  ../nidan-docker/openelis/volume/plugins/
docker compose --profile openelis restart openelis
```

## Start the bridge

```bash
docker compose --profile openelis up -d openelis-analyzer-bridge
```

## Ports (host → container) — current Nidan remap

This lab’s XN-350 talks **E1381-95 (no ENQ)** on the port it labels as Host **12000**, so compose maps:

| Host | Container | Protocol |
|------|-----------|----------|
| 8442 | 8443 | Bridge HTTPS / health |
| **12000** | **12011** | **ASTM E1381-95** (plain TCP) — XN-350 default here |
| **12010** | **12001** | ASTM E1381-02 / LIS1-A (ENQ/ACK) |
| 2575 | 2575 | HL7 MLLP |

Health: `curl -sk https://localhost:8442/actuator/health`

## XN-350 IPU settings (this site)

| Setting | Value |
|---------|-------|
| Connection | TCP/IP |
| Protocol | **ASTM 1381-95 / 1394-97** (or whatever label sends no ENQ) |
| Host IP | Docker host LAN IP (e.g. `192.168.10.112`) |
| Host port | **12000** |

## Routing note (important)

Bridge **v3.0.4** defaults `bridge.routing.useFhir: true`. That path converts ASTM→FHIR and fails on Sysmex CBC messages (`FHIR parse produced no results`).  
`configuration.yml` sets `useFhir: false` so raw ASTM is POSTed to OpenELIS `/analyzer/astm` for the **SysmexXN-L** plugin (needs `OPENELIS_USERNAME` / `OPENELIS_PASSWORD`).

## Analyzer IP registry

`bridge.analyzers` keys **must** use bracket form for IPs:

```yaml
bridge:
  analyzers:
    "[192.168.10.113]":
      id: SYSMEX-XN350-001
      name: "Sysmex XN-350"
      expectedProtocol: ASTM
```

Without brackets, the bridge YAML loader treats `192.168.10.113` as nested path segments and the registry stays empty (`Source '…' not in local registry`). Docker Desktop often shows a NAT IP (e.g. `167.82.48.223`) instead of the analyzer LAN IP — register both if needed.

Check: `curl -sk -u bridge:$PASS https://localhost:8442/api/analyzers`

## Troubleshooting

### `FHIR parse produced no results for ASTM message`

FHIR routing is still on. Confirm config has `bridge.routing.useFhir: false`, then recreate the bridge:

```bash
docker compose --profile openelis up -d --force-recreate openelis-analyzer-bridge
```

### `ASTMCommunicationException: non compliant mode…` / wrong start character

Wrong ASTM framing vs listener port. With current remap, keep Host port **12000** for non-ENQ traffic.

### `No ASTM plugin matched this message`

SysmexXN-L JAR missing/not loaded, or H-record model token not recognized as XN-350 / XN-L.

Check live logs:

```bash
docker logs -f nidan-openelis-analyzer-bridge
docker logs nidan-openelis 2>&1 | grep -i Sysmex
```

Success: bridge forwards HTTP 200 to OE; results show under **Results → Analyzer → Sysmex XNL** (sample must exist / tests ordered).
