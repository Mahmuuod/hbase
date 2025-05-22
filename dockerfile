FROM ubuntu:22.04 AS hadoop
# Install all required packages in one layer
RUN apt update -y && \
    apt upgrade -y && \
    DEBIAN_FRONTEND=noninteractive apt install -y \
    net-tools \
    netcat \
    ssh \
    sshpass \
    openjdk-8-jdk \
    sudo \
    vim \
    wget \
    tar && \
    # Download and extract Hadoop
    wget https://dlcdn.apache.org/hadoop/common/hadoop-3.3.6/hadoop-3.3.6.tar.gz && \
    tar -xzf hadoop-3.3.6.tar.gz -C /opt && \
    rm hadoop-3.3.6.tar.gz && \
    # Download and extract Zookeeper
    mkdir -p /opt/zookeeper && \
    wget https://dlcdn.apache.org/zookeeper/zookeeper-3.8.4/apache-zookeeper-3.8.4-bin.tar.gz && \
    tar -xzf apache-zookeeper-3.8.4-bin.tar.gz -C /opt/zookeeper && \
    mv /opt/zookeeper/apache-zookeeper-3.8.4-bin /opt/zookeeper/zookeeper && \
    rm apache-zookeeper-3.8.4-bin.tar.gz && \
    # Create hadoop user
    adduser --disabled-password --gecos "" hadoop && \
    echo "hadoop:123" | chpasswd && \
    usermod -aG sudo hadoop && \
    echo "hadoop ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/hadoop

USER hadoop
WORKDIR /home/hadoop

# SSH setup and directory preparation
RUN mkdir -p ~/.ssh && \
    ssh-keygen -t rsa -N '' -f ~/.ssh/id_rsa && \
    cat ~/.ssh/id_rsa.pub >> ~/.ssh/authorized_keys && \
    chmod 700 ~/.ssh && chmod 600 ~/.ssh/authorized_keys && \
    sudo mkdir -p /opt/hadoop/name /opt/hadoop/journal /opt/hadoop/data && \
    sudo mkdir -p /opt/zookeeper/data /opt/zookeeper/log && \
    sudo chown -R hadoop:hadoop /opt/hadoop /opt/zookeeper /opt/hadoop-3.3.6

# Copy configuration and bootstrap script
COPY --chown=hadoop:hadoop --chmod=755 ./data/configs/hadoop/* /opt/hadoop-3.3.6/etc/hadoop/
COPY --chown=hadoop:hadoop --chmod=755 ./data/configs/zoo.cfg /opt/zookeeper/zookeeper/conf/
COPY --chown=hadoop:hadoop --chmod=755 ./code/hadoop_script.sh /home/hadoop/code/

# Environment setup
ENV JAVA_HOME=/usr/lib/jvm/java-1.8.0-openjdk-amd64 \
    HADOOP_HOME=/opt/hadoop-3.3.6 \
    HADOOP_CONF_DIR=/opt/hadoop-3.3.6/etc/hadoop \
    ZOOKEEPER_HOME=/opt/zookeeper/zookeeper \
    PATH=$PATH:/opt/hadoop-3.3.6/bin:/opt/hadoop-3.3.6/sbin:/opt/zookeeper/zookeeper/bin
RUN sudo mkdir -p /run/sshd && sudo  chmod 755 /run/sshd
ENTRYPOINT ["/bin/bash", "-c", " /home/hadoop/code/hadoop_script.sh"]


FROM hadoop AS hbase

USER root
ADD https://dlcdn.apache.org/hbase/2.5.11/hbase-2.5.11-bin.tar.gz /tmp/
RUN tar -xzf /tmp/hbase-2.5.11-bin.tar.gz -C /opt \
    && mv /opt/hbase-2.5.11 /opt/hbase \
    && rm /tmp/hbase-2.5.11-bin.tar.gz && chown -R hadoop:hadoop /opt/hbase
ENV HBASE_HOME=/opt/hbase
ENV PATH=$HBASE_HOME/bin:$PATH



USER hadoop

COPY /data/configs/hbase/hbase-site.xml $HBASE_HOME/conf/hbase-site.xml

WORKDIR /home/hadoop

ENTRYPOINT ["/bin/bash", "-c", " /home/hadoop/code/hadoop_script.sh"]