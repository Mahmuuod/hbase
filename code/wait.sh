
while ! nc -z Worker1 8485 || ! nc -z Master1 8485 || ! nc -z Master2 8485 || ! nc -z Master3 8485; do
    echo "Waiting for Journal Nodes on all nodes..."
    sleep 2
done

echo 'all nodes are up '

while ! nc -z Worker1 22 || ! nc -z Master1 22 || ! nc -z Master2 22 || ! nc -z Master3 22; do
    echo "Waiting for SSH access on all nodes..."
    sleep 2
done
echo 'All SSH Are On '


while [ ! -d "/opt/hadoop/journal/mycluster" ]; do
    echo "Waiting for Data Node To Be Formatted ..."
    sleep 2
done
echo 'node formatted'
