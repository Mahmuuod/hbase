
set -e
HADOOP_HOME="/data/hadoop-3.3.6"
HADOOP_CONF_DIR="$HADOOP_HOME/etc/hadoop"
NAMENODE_DIR="/opt/hadoop/name"
JOURNAL_DIR="/opt/hadoop/journal"
ZOOKEEPER_DATA="/opt/zookeeper/data"
ZOOKEEPER_LOG="/opt/zookeeper/log"
NODE=$(hostname)

case "$NODE" in
    "Master1" | "Master2" | "Master3")
        mkdir -p ~/.ssh/
        sudo mkdir -p /opt/hadoop/name
        sudo mkdir -p /opt/hadoop/journal
        sudo mkdir -p /opt/zookeeper/data
        sudo mkdir -p /opt/zookeeper/log
        sudo chown -R hadoop:hadoop /opt/hadoop
        sudo chown -R hadoop:hadoop /opt/zookeeper
        sudo chown -R hadoop:hadoop /data/zookeeper/
        ;;
    Worker*)
        mkdir -p .ssh/ 
        ;;
    *)
        echo "Unknown node type: $NODE. No specific configuration applied."
        ;;
esac

# Configure SSH
while ! nc -z Worker1 22 || ! nc -z Master1 22 || ! nc -z Master2 22 || ! nc -z Master3 22; do
    echo "Waiting for SSH access on all nodes..."
    sleep 2
done
echo 'All SSH Are On '

ssh-keyscan -H master1 worker1 master2 master3 >> ~/.ssh/known_hosts
ssh-keygen -t rsa -b 4096 -N "" -f ~/.ssh/id_rsa 
sshpass -p "123" ssh-copy-id -o StrictHostKeyChecking=no -i ~/.ssh/id_rsa.pub hadoop@master1 
sshpass -p "123" ssh-copy-id -o StrictHostKeyChecking=no -i ~/.ssh/id_rsa.pub hadoop@worker1  
sshpass -p "123" ssh-copy-id -o StrictHostKeyChecking=no -i ~/.ssh/id_rsa.pub hadoop@master2 
sshpass -p "123" ssh-copy-id -o StrictHostKeyChecking=no -i ~/.ssh/id_rsa.pub hadoop@master3 
cat ~/.ssh/id_rsa.pub >> /data/shared/authorized_keys

echo export JAVA_HOME=/usr/lib/jvm/java-1.8.0-openjdk-amd64 >> .profile 
echo export HADOOP_CONF_DIR=/data/hadoop-3.3.6/etc/hadoop/ >> .profile
echo export HADOOP_HOME=/data/hadoop-3.3.6 >>.profile
echo 'export PATH=$PATH:$HADOOP_HOME/bin:$HADOOP_HOME/sbin:/data/zookeeper/bin/' >> .profile 
echo sudo service ssh start >> .profile 
source ~/.profile

case "$NODE" in
    "Master1" | "Master2" | "Master3")
        echo 'hdfs --daemon start journalnode && hdfs --daemon start namenode && yarn --daemon start resourcemanager && zkServer.sh start && hdfs --daemon start zkfc' >> .profile
        ;;
    Worker* )
        cp /data/shared/authorized_keys ~/.ssh/authorized_keys
        echo 'hdfs --daemon start datanode && yarn --daemon start nodemanager' >> .profile
        ;;
    *)
        echo "Unknown node type: $NODE. No specific configuration applied."
        ;;
esac


case "$NODE" in
    "Master1" ) 
    hdfs --daemon start journalnode  
    echo 1 > /opt/zookeeper/data/myid 
    zkServer.sh start
        ;;
    "Master2" ) 
    hdfs --daemon start journalnode  
    echo 2 > /opt/zookeeper/data/myid 
    zkServer.sh start
        ;;
    "Master3")
    hdfs --daemon start journalnode  
    echo 3 > /opt/zookeeper/data/myid 
    zkServer.sh start
        ;;
    Worker* )
        ;;
    *)
        echo "Unknown node type: $NODE. No specific configuration applied."
        ;;
esac


echo 'all nodes are up '

case "$NODE" in
    "Master1" ) 
    while ! nc -z Master1 8485 || ! nc -z Master2 8485 || ! nc -z Master3 8485; do
        echo "Waiting for Journal Nodes on all nodes..."
        sleep 2
    done
    hdfs namenode -format  
    hdfs --daemon start namenode  
    hdfs zkfc -formatZK 
    hdfs --daemon start zkfc 
    yarn --daemon start resourcemanager
        ;;
    "Master2" | "Master3" ) 
        while [ ! -d "/opt/hadoop/journal/mycluster" ]; do
            echo "Waiting for Name Node To Be Formatted ..."
            sleep 2
        done
    sleep 5
    hdfs namenode -bootstrapStandby
    hdfs --daemon start namenode
    yarn --daemon start resourcemanager
    hdfs --daemon start zkfc
        ;;
    Worker* )
    hdfs --daemon start datanode 
    yarn --daemon start nodemanager
        ;;
    *)
        echo "Unknown node type: $NODE. No specific configuration applied."
        ;;
esac

echo "$(hostname), Succeed"