set -e

if  ! id "hadoop" &>/dev/null ; then
apt update -y  
apt upgrade -y
apt install -y ssh
apt install -y  vim
apt install -y sudo
apt install -y openjdk-8-jdk
apt install -y sshpass
apt install netcat -y
apt install net-tools


    sudo adduser --disabled-password --gecos "" hadoop 
    echo "hadoop:123" | sudo chpasswd 
    sudo usermod -aG sudo hadoop 
    echo "hadoop ALL=(ALL) NOPASSWD:ALL" | sudo tee -a /etc/sudoers.d/hadoop
    sudo service ssh start 
    echo su - hadoop >> ~/.bashrc 
    su - hadoop -c "bash /code/hadoop_script2.sh"
else
    su - hadoop
fi
