#!/bin/bash
set -e

NODE=$(hostname)
NodeID=$(echo "$NODE" | grep -o '[0-9]\+$')
echo "------------ $NodeID"
sudo service ssh start

cd ~

if [ ! -d /opt/hadoop/name/current ]; then
    echo "Starting cluster initialization..."

    case "$NODE" in
        master* )
            hdfs --daemon start journalnode
            while ! nc -z localhost 8485; do
                echo "Waiting for Journal Node on localhost..."
                sleep 2
            done
            sleep 5

            if [ "$NodeID" = "1" ]; then
                echo "Formatting NameNode and ZKFC on Master1..."
                hdfs namenode -format
                hdfs zkfc -formatZK
                hdfs --daemon start namenode
                hdfs --daemon start zkfc
                yarn --daemon start resourcemanager
            else
                echo "Waiting for Master1 NameNode to be formatted..."
                while ! nc -z Master1 9870; do
                    echo "Waiting for NameNode on Master1..."
                    sleep 2
                done

                echo "Waiting for zkfc on Master1 to be alive..."
                while ! nc -z Master1 8019; do
                    echo "Waiting for zkfc on Master1..."
                    sleep 2
                done
                echo "Bootstrapping standby NameNode on $NODE..."
                sleep 5
                hdfs namenode -bootstrapStandby
                hdfs --daemon start namenode


                hdfs --daemon start zkfc
                yarn --daemon start resourcemanager
            fi
            ;;
        worker* )
            hdfs --daemon start datanode
            yarn --daemon start nodemanager
            hbase-daemon.sh start regionserver
            ;;
        zk* )
        sudo echo $NodeID > /opt/zookeeper/data/myid 
        zkServer.sh start
            ;;
        hmaster* )
            hdfs dfs -mkdir -p /hbase && hdfs dfs -chown hadoop:hadoop /hbase
            hbase master start
        ;;
        *)  
            echo "Unknown node type: $NODE. No specific configuration applied."
            ;;
    esac

    echo "All nodes are up"
    echo "$(hostname), Succeeded"

else
    echo "Starting cluster services..."

    case "$NODE" in
        master* )
            hdfs --daemon start journalnode
            hdfs --daemon start namenode
            hdfs --daemon start zkfc
            yarn --daemon start resourcemanager
            ;;
        worker* )
            hdfs --daemon start datanode
            yarn --daemon start nodemanager
            hbase-daemon.sh start regionserver

            ;;
        zk* )
            zkServer.sh start
            ;;
        hmaster* )
            hbase master start
        ;;
        *)
            echo "Unknown node type: $NODE. No specific configuration applied."
            ;;
    esac
fi

tail -f /dev/null & wait
