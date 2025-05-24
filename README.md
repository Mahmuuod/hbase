# Highly Available HBase Cluster & WebTable Use Case

## Project Overview

This project demonstrates the design, deployment, and usage of a **Highly Available (HA) HBase cluster** integrated with an HA Hadoop cluster, along with a WebTable use case showcasing web page storage, metadata management, and link analysis.

---

## Architecture & Cluster Setup

- **Hadoop Masters:**

  - Hadoop NameNode(s) with JournalNodes for HDFS HA
  - YARN ResourceManager(s) with HA
 
 - **Hbase Masters:** 
  - HBase Master node(s) with active/standby failover (2)

- **Zookeeper Nodes:**
  - ZooKeeper ensemble (3 nodes)
 
- **Workers:**
  - HBase RegionServers
  - Hadoop DataNodes
  - YARN NodeManagers

- **Containerization:**
  - Custom Docker image including Hadoop 3.3.6, Zookeeper 3.8.4, HBase 2.5.11
  - Docker Compose orchestrates a multi-container HA cluster deployment
---

# 🐳 Dockerfile Documentation: Hadoop + Zookeeper + HBase Cluster

This multi-stage Dockerfile builds two images:
1. A base image with **Hadoop 3.3.6** and **Zookeeper 3.8.4**
2. An extended image with **HBase 2.5.11**

It is optimized for setting up a high-availability Hadoop + HBase cluster using Docker and Docker Compose.

---

## 🧱 Stage 1: Base Hadoop Image (`hadoop`)

### Base OS
```dockerfile
FROM ubuntu:22.04 AS hadoop
```

### Installed Tools and Dependencies
- `openjdk-8-jdk` for Hadoop and HBase compatibility
- SSH (`ssh`, `sshpass`) for intra-cluster communication
- Network utilities (`netcat`, `net-tools`)
- System tools (`sudo`, `vim`, `wget`, `tar`)

### Hadoop Installation
```bash
wget https://dlcdn.apache.org/hadoop/common/hadoop-3.3.6/hadoop-3.3.6.tar.gz
```
- Extracted into `/opt/hadoop-3.3.6`

### Zookeeper Installation
```bash
wget https://dlcdn.apache.org/zookeeper/zookeeper-3.8.4/apache-zookeeper-3.8.4-bin.tar.gz
```
- Extracted to `/opt/zookeeper/zookeeper`

### Hadoop User Setup
- Creates `hadoop` user with `sudo` privileges
- Password: `123`
- SSH key generation for passwordless login

### Configuration Files
```dockerfile
COPY ./data/configs/hadoop/* → /opt/hadoop-3.3.6/etc/hadoop/
COPY ./data/configs/zoo.cfg → /opt/zookeeper/zookeeper/conf/
COPY ./code/hadoop_script.sh → /home/hadoop/code/
```

### Environment Variables
```dockerfile
JAVA_HOME, HADOOP_HOME, HADOOP_CONF_DIR, ZOOKEEPER_HOME
```

### Entrypoint
```bash
ENTRYPOINT ["/bin/bash", "-c", " /home/hadoop/code/hadoop_script.sh"]
```

---

## 🧪 Stage 2: Extended HBase Image (`hbase`)

```dockerfile
FROM hadoop AS hbase
```

### Adds HBase 2.5.11
```bash
wget https://dlcdn.apache.org/hbase/2.5.11/hbase-2.5.11-bin.tar.gz
```
- Extracted into `/opt/hbase`
- Config file copied: `hbase-site.xml`

### Additional Environment Variables
```dockerfile
HBASE_HOME=/opt/hbase
PATH=$HBASE_HOME/bin:$PATH
```

### Entrypoint
Uses the same bootstrap script: `hadoop_script.sh`

---

## 🧤 Final Notes

- Multi-stage build minimizes image size and organizes layers.
- This image is compatible with HA setups for Hadoop + HBase + Zookeeper.
- SSH setup allows container-to-container remote command execution.

---
---
## Compose
---

## 📦 Cluster Components Overview

### 🟩 Hadoop Masters

- **Hadoop NameNodes**: Provide HDFS master services with High Availability enabled using JournalNodes.
- **YARN ResourceManagers**: Handle job scheduling and resource allocation with HA failover support.

### 🟨 HBase Masters

- **HBase Master Nodes**: Two nodes configured for active/standby mode to provide fault-tolerant region management and metadata handling.

### 🟦 ZooKeeper Nodes

- **ZooKeeper Ensemble**: Three nodes forming a quorum to coordinate leader election and distributed synchronization for Hadoop and HBase.

### 🟧 Workers

- **HBase RegionServers**: Handle read/write operations for HBase tables and serve regions to clients.
- **Hadoop DataNodes**: Store HDFS data blocks.
- **YARN NodeManagers**: Manage containers and monitor resource usage on each worker node.

---

## 🐳 Containerization and Build Info

- **Custom Docker Image**:
  - Hadoop 3.3.6
  - Zookeeper 3.8.4
  - HBase 2.5.11
- Each node is built from this custom image using multi-stage builds.
- Docker Compose simulates a distributed environment with HA behavior.

---

## 🌐 Networking

All services communicate over a custom Docker bridge network called `hadoop_cluster`, ensuring internal hostname resolution between containers.

---

## 🗃️ Persistent Volumes

Named volumes are created for:

- **NameNode directories** (`nn1`, `nn2`)
- **Zookeeper data directories** (`zk1`, `zk2`, `zk3`)
- **DataNode storage**
- Additional persistent mounts for logs and code are bind-mounted from host

---

## 🚀 Running the Cluster

```bash
# Build the cluster images
docker-compose build

# Start all services
docker-compose up -d

# Monitor the state
docker ps
docker logs -f <service_name>
```

## WebTable Use Case

- Stores web pages with four column families:

  | Family   | Purpose              | Versions | TTL (seconds)     | Bloom Filter |
  |----------|----------------------|----------|-------------------|--------------|
  | content  | HTML content and text| 3        | 7,776,000 (90 days)| ROW          |
  | meta     | Metadata (status, fetch time)| 1  | 2,147,483,647 (no TTL)| ROW          |
  | outlinks | Outbound links       | 2        | 15,552,000 (180 days)| ROWCOL       |
  | inlinks  | Inbound links        | 2        | 15,552,000 (180 days)| ROWCOL       |

- Row keys are **salted and reversed URLs**, e.g., `a!com.example.www/page-1`, to ensure data distribution and scan efficiency.

---

## Usage Examples

### Basic Commands

- Retrieve a page by row key:

  ```hbase
  get 'webTable', 'a!com.example.www/page-1'

  ## 🧱 Table Design Overview

### Column Families

The table defines **four column families**, each with specific settings tailored for different access patterns:

---

### 1. `content`

- **Purpose**: Stores the main content of a webpage (e.g., HTML, text).
- **BLOOMFILTER**: `ROW` — optimized for lookups by row key.
- **BLOCKSIZE**: `65536` bytes (64 KB) — suited for larger values like full HTML pages.
- **BLOCKCACHE**: `true` — enables in-memory caching of blocks to improve read speed.
- **IN_MEMORY**: `true` — keeps data in memory for fast access (only viable if memory allows).
- **VERSIONS**: `1` — only the latest version of each cell is retained.

---

### 2. `meta`

- **Purpose**: Stores metadata such as titles, headers, timestamps.
- **BLOOMFILTER**: `ROW` — fast row-level lookups.
- **BLOCKSIZE**: `16384` bytes (16 KB) — smaller data blocks for lightweight metadata.
- **BLOCKCACHE**: `true` — metadata is likely to be reused, so caching is beneficial.
- **VERSIONS**: `1` — only the most recent metadata is needed.

---

### 3. `outlinks`

- **Purpose**: Stores links from the page to others (outbound links).
- **BLOOMFILTER**: `ROWCOL` — optimized for access to specific link values by row and column.
- **BLOCKSIZE**: `32768` bytes (32 KB) — moderate block size for lists of links.
- **VERSIONS**: `1` — only the latest state of links is retained.

---

### 4. `inlinks`

- **Purpose**: Stores backlinks from other pages (who links to this page).
- **BLOOMFILTER**: `ROWCOL` — enables precise lookup for specific incoming links.
- **BLOCKSIZE**: `32768` bytes (32 KB).
- **VERSIONS**: `1`.

---

## 🧂 Region Pre-splitting with Salts

```ruby
['0!', '1!', '2!', '3!', '4!', '5!', '6!', '7!', '8!', '9!', 'a!', 'b!', 'c!', 'd!', 'e!', 'f!']

```


```
create 'webTable', 
  {NAME => 'content', 
   BLOOMFILTER => 'ROW',         
   BLOCKSIZE => 65536,
   BLOCKCACHE => true,
   IN_MEMORY => true,
   VERSIONS => 3,
   TTL => 7776000},        

  {NAME => 'meta', 
   BLOOMFILTER => 'ROW',         
   BLOCKSIZE => 16384,
   BLOCKCACHE => true,
   VERSIONS => 1,
   TTL => 2147483647},      

  {NAME => 'outlinks', 
   BLOOMFILTER => 'ROWCOL',       
   BLOCKSIZE => 32768,
   VERSIONS => 2,
   TTL => 15552000},       

  {NAME => 'inlinks', 
   BLOOMFILTER => 'ROWCOL',      
   BLOCKSIZE => 32768,
   VERSIONS => 2,
   TTL => 15552000},

  ['0!', '1!', '2!', '3!', '4!', '5!', '6!', '7!', '8!', '9!', 'a!', 'b!', 'c!', 'd!', 'e!', 'f!']
```
