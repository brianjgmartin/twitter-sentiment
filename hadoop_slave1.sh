#!/bin/bash

# Launch Instance and save instance ID 
# to variable "HADOOP_SLAVE1_INST_ID"
HADOOP_SLAVE1_INST_ID="$(aws ec2 run-instances \
	--image-id ami-f0b11187 \
	--instance-type t2.micro \
	--key-name  irishkey \
	--security-groups  launch-wizard-7 \
	--region eu-west-1 | grep INSTANCE | awk '{print $8}')"

# Name The Instance by using 
# ${HADOOP_SLAVE1_INST_ID}
aws ec2 create-tags \
--resources ${HADOOP_SLAVE1_INST_ID} \
--tag Key=Name,Value=HadoopSlave1
sleep 60

# Get Public IP Address of Hadoop Name Node
PUB_IP_ADRS_HDSLV1="$(aws ec2 describe-instances \
 	--filters 'Name=tag:Name,Values=HadoopSlave1' \
 	--output text \
 	--query 'Reservations[*].Instances[*].PublicIpAddress')"

# Save Private IP Address of instance to Variable
HDSLV1_INETADRS="$(aws ec2 describe-instances \
	--filters 'Name=tag:Name,Values=HadoopSlave1' \
	--output text \
	--query 'Reservations[*].Instances[*].PrivateIpAddress')"

# Save Public DNS of instance to Variable
HDSLV1_PUBDNS="$(aws ec2 describe-instances \
	--filters 'Name=tag:Name,Values=HadoopSlave1' \
	--output text \
	--query 'Reservations[*].Instances[*].PublicDnsName')"

#ssh Into HadoopSlave1 and configure Instance 
ssh -i ~/.ssh/irishkey.pem ubuntu@${PUB_IP_ADRS_HDSLV1} bash -c "'
sudo hostname $HDSLV1_PUBDNS 
sudo sed -i 's/127.0.0.1/$HDSLV1_INETADRS/g' /etc/hosts
sudo sed -i 's/localhost/$HDSLV1_PUBDNS/g' /etc/hosts
sudo echo oracle-java7-installer shared/accepted-oracle-license-v1-1 select true | sudo /usr/bin/debconf-set-selections
sudo apt-get update -y
sudo add-apt-repository ppa:webupd8team/java -y
sudo apt-get update && sudo apt-get install oracle-jdk7-installer -y
wget http://apache.mirror.gtcomm.net/hadoop/common/hadoop-1.2.1/hadoop-1.2.1.tar.gz
tar -xzvf hadoop-1.2.1.tar.gz
mv hadoop-1.2.1 hadoop
echo $INETADRS 
echo "'export HADOOP_CONF=/home/ubuntu/hadoop/conf'" >> ~/.bashrc
echo "'export HADOOP_PREFIX=/home/ubuntu/hadoop'" >> ~/.bashrc
echo "'export JAVA_HOME=/usr/lib/jvm/java-7-oracle'" >> ~/.bashrc
echo "export PATH=$PATH:$HADOOP_PREFIX/bin" >> ~/.bashrc
source ~/.bashrc
sed -i  '9s/^..//' /home/ubuntu/hadoop/conf/hadoop-env.sh
sed -i 's@JAVA_HOME=/usr/lib/j2sdk1.5-sun@JAVA_HOME=/usr/lib/jvm/java-7-oracle@g' /home/ubuntu/hadoop/conf/hadoop-env.sh
mkdir hdfstmp
'"