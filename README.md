# Highly Available HBase Cluster & WebTable Use Case

## Project Overview

This project demonstrates the design, deployment, and usage of a **Highly Available (HA) HBase cluster** integrated with an HA Hadoop cluster, along with a WebTable use case showcasing web page storage, metadata management, and link analysis.

---

## Architecture & Cluster Setup

- **Masters:**
  - HBase Master node(s) with active/standby failover
  - Hadoop NameNode(s) with JournalNodes for HDFS HA
  - YARN ResourceManager(s) with HA
  - ZooKeeper ensemble (3 nodes)

- **Workers:**
  - HBase RegionServers
  - Hadoop DataNodes
  - YARN NodeManagers

- **Containerization:**
  - Custom Docker image including Hadoop 3.3.6, Zookeeper 3.8.4, HBase 2.5.11
  - Docker Compose orchestrates multi-container HA cluster deployment

---

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
