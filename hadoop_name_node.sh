#!/bin/bash

# Launch Instance and save instance ID 
# to variable "HADOOP_NODE_NAME_INST_ID"
HADOOP_NODE_NAME_INST_ID="$(aws ec2 run-instances \
	--image-id ami-f0b11187 \
	--instance-type t2.micro \
	--key-name  irishkey \
	--security-groups  launch-wizard-7 \
	--region eu-west-1 | grep INSTANCE | awk '{print $8}')"

# Name The Instance by using 
# ${HADOOP_NODE_NAME_INST_ID}
aws ec2 create-tags \
--resources ${HADOOP_NODE_NAME_INST_ID} \
--tag Key=Name,Value=HadoopNameNode
sleep 60

# Get Public IP Address of Hadoop Name Node
PUB_IP_ADRS_HDNN="$(aws ec2 describe-instances \
 	--filters 'Name=tag:Name,Values=HadoopNameNode' \
 	--output text \
 	--query 'Reservations[*].Instances[*].PublicIpAddress')"

# Save Private IP Address of instance to Variable
INETADRS="$(aws ec2 describe-instances \
	--filters 'Name=tag:Name,Values=HadoopNameNode' \
	--output text \
	--query 'Reservations[*].Instances[*].PrivateIpAddress')"

# Save Public DNS of instance to Variable
PUBDNS="$(aws ec2 describe-instances \
	--filters 'Name=tag:Name,Values=HadoopNameNode' \
	--output text \
	--query 'Reservations[*].Instances[*].PublicDnsName')"

# Create file required for Hadoop core-site.xml
# This file will be copied over to HadoopNameNode
# The Contents of this file will be written to 
# core-site.xml file when hadoop is created
cat >> core-site <<EOF
<property>
<name>fs.default.name</name>
<value>hdfs://${PUBDNS}:8020</value>
</property>

<property>
<name>hadoop.tmp.dir</name>
<value>/home/ubuntu/hdfstmp</value>
</property>
EOF

# Create file required for Hadoop hdfs-site.xml
# This file will be copied over to HadoopNameNode
# The Contents of this file will be written to 
# hdfs-site.xml file when hadoop is created
cat >> hdfs-site <<EOF
<property>
<name>dfs.replication</name>
<value>2</value>
</property>

<property>
<name>dfs.permissions</name>
<value>false</value>
</property>
EOF

# Create file required for Hadoop mapred-site.xml
# This file will be copied over to HadoopNameNode
# The Contents of this file will be written to 
# mapred-site.xml file when hadoop is created
cat >> mapred-site <<EOF
<property>
<name>mapred.job.tracker</name>
<value>hdfs://${PUBDNS}:8021</value>
</property>
EOF


# Copy Key to ec2 HAdoop_Name_Node 
# This will allow Hadoop_Name_Node To access Slaves and start Daemons
scp -i ~/.ssh/irishkey.pem  ~/.ssh/irishkey.pem ubuntu@${PUB_IP_ADRS_HDNN}:

# Copy over core-site file to HadoopNameNode
scp -i ~/.ssh/irishkey.pem  ./core-site ubuntu@${PUB_IP_ADRS_HDNN}:
rm core-site

# Copy over hdfs-site file to HadoopNameNode
scp -i ~/.ssh/irishkey.pem  ./hdfs-site ubuntu@${PUB_IP_ADRS_HDNN}:
rm hdfs-site

# Copy over mapred-site file to HadoopNameNode
scp -i ~/.ssh/irishkey.pem  ./mapred-site ubuntu@${PUB_IP_ADRS_HDNN}:
rm mapred-site

scp -i ~/.ssh/irishkey.pem  ~/.ssh/config ubuntu@${PUB_IP_ADRS_HDNN}:/home/ubuntu/.ssh/

#ssh Into HadoopNameNode and configure Instance 
ssh -i ~/.ssh/irishkey.pem ubuntu@${PUB_IP_ADRS_HDNN} bash -c "'
sudo hostname $PUBDNS 
sudo sed -i 's/127.0.0.1/$INETADRS/g' /etc/hosts
sudo sed -i 's/localhost/$PUBDNS/g' /etc/hosts
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
echo hello
mkdir hdfstmp
# The core-site file which was copied over earlier
# will be inserted to core-site.xml
sed -i "'/\<configuration\>/r\/home\/ubuntu\/core-site'" /home/ubuntu/hadoop/conf/core-site.xml
sed -i "'/\<configuration\>/r\/home\/ubuntu\/hdfs-site'" /home/ubuntu/hadoop/conf/hdfs-site.xml
sed -i "'/\<configuration\>/r\/home\/ubuntu\/mapred-site'" /home/ubuntu/hadoop/conf/mapred-site.xml
# Add $PUBDNS to masters file
sudo sed -i 's/localhost/$PUBDNS/g' /home/ubuntu/hadoop/conf/masters
'"

# Create and source hadoop_secondary_name_node
source ./hadoop_secondary_name_node.sh

# Create and source hadoop_slave1_node
source ./hadoop_slave1.sh

# Create and source hadoop_slave1_node
source ./hadoop_slave2.sh

# ssh into HadoopNameNode, Add $HDSNN_PUBDNS to masters file
# Copy core-site, hdfs-site, mapred-site to HadoopSecondaryNameNode
ssh -i ~/.ssh/irishkey.pem ubuntu@${PUB_IP_ADRS_HDNN} bash -c "'
echo "$HDSNN_PUBDNS" >> /home/ubuntu/hadoop/conf/masters
scp -i /home/ubuntu/irishkey.pem  /home/ubuntu/hadoop/conf/core-site.xml ubuntu@${PUB_IP_ADRS_HDSNN}:/home/ubuntu/hadoop/conf
scp -i /home/ubuntu/irishkey.pem  /home/ubuntu/hadoop/conf/hdfs-site.xml ubuntu@${PUB_IP_ADRS_HDSNN}:/home/ubuntu/hadoop/conf
scp -i /home/ubuntu/irishkey.pem  /home/ubuntu/hadoop/conf/mapred-site.xml ubuntu@${PUB_IP_ADRS_HDSNN}:/home/ubuntu/hadoop/conf
scp -i /home/ubuntu/irishkey.pem  /home/ubuntu/hadoop/conf/core-site.xml ubuntu@${PUB_IP_ADRS_HDSLV1}:/home/ubuntu/hadoop/conf
scp -i /home/ubuntu/irishkey.pem  /home/ubuntu/hadoop/conf/hdfs-site.xml ubuntu@${PUB_IP_ADRS_HDSLV1}:/home/ubuntu/hadoop/conf
scp -i /home/ubuntu/irishkey.pem  /home/ubuntu/hadoop/conf/mapred-site.xml ubuntu@${PUB_IP_ADRS_HDSLV1}:/home/ubuntu/hadoop/conf
scp -i /home/ubuntu/irishkey.pem  /home/ubuntu/hadoop/conf/core-site.xml ubuntu@${PUB_IP_ADRS_HDSLV2}:/home/ubuntu/hadoop/conf
scp -i /home/ubuntu/irishkey.pem  /home/ubuntu/hadoop/conf/hdfs-site.xml ubuntu@${PUB_IP_ADRS_HDSLV2}:/home/ubuntu/hadoop/conf
scp -i /home/ubuntu/irishkey.pem  /home/ubuntu/hadoop/conf/mapred-site.xml ubuntu@${PUB_IP_ADRS_HDSLV2}:/home/ubuntu/hadoop/conf
echo "$HDSLV1_PUBDNS" >> /home/ubuntu/hadoop/conf/slaves
echo "$HDSLV2_PUBDNS" >> /home/ubuntu/hadoop/conf/slaves
scp -i /home/ubuntu/irishkey.pem  /home/ubuntu/hadoop/conf/masters /home/ubuntu/hadoop/conf/slaves ubuntu@${PUB_IP_ADRS_HDSNN}:/home/ubuntu/hadoop/conf
'"

ssh -i ~/.ssh/irishkey.pem ubuntu@${PUB_IP_ADRS_HDSLV1} bash -c "'
sed -i  's/localhost//' /home/ubuntu/hadoop/conf/masters
sudo sed -i 's/localhost/$HDSLV1_PUBDNS/g' /home/ubuntu/hadoop/conf/slaves
'"

ssh -i ~/.ssh/irishkey.pem ubuntu@${PUB_IP_ADRS_HDSLV2} bash -c "'
sed -i  's/localhost//' /home/ubuntu/hadoop/conf/masters
sudo sed -i 's/localhost/$HDSLV2_PUBDNS/g' /home/ubuntu/hadoop/conf/slaves
'"


# ssh -i ~/.ssh/irishkey.pem ubuntu@${PUB_IP_ADRS_HDNN} bash -c "'
# scp -i /home/ubuntu/irishkey.pem  /home/ubuntu/hadoop/conf/core-site.xml ubuntu@${PUB_IP_ADRS_HDSLV1}:/home/ubuntu/hadoop/conf
# scp -i /home/ubuntu/irishkey.pem  /home/ubuntu/hadoop/conf/hdfs-site.xml ubuntu@${PUB_IP_ADRS_HDSLV1}:/home/ubuntu/hadoop/conf
# scp -i /home/ubuntu/irishkey.pem  /home/ubuntu/hadoop/conf/mapred-site.xml ubuntu@${PUB_IP_ADRS_HDSLV1}:/home/ubuntu/hadoop/conf
# echo Hello
# '"

# source ./hadoop_slave2.sh


#  	ssh -i ~/.ssh/irishkey.pem ubuntu@${PUB_IP_ADRS_HDNN} bash -c "'
# scp -i /home/ubuntu/irishkey.pem  /home/ubuntu/hadoop/conf/core-site.xml ubuntu@${PUB_IP_ADRS_HDSLV2}:/home/ubuntu/hadoop/conf
# scp -i /home/ubuntu/irishkey.pem  /home/ubuntu/hadoop/conf/hdfs-site.xml ubuntu@${PUB_IP_ADRS_HDSLV2}:/home/ubuntu/hadoop/conf
# scp -i /home/ubuntu/irishkey.pem  /home/ubuntu/hadoop/conf/mapred-site.xml ubuntu@${PUB_IP_ADRS_HDSLV2}:/home/ubuntu/hadoop/conf
# '"

# # Get Public IP Address of Hadoop Name Node
# PUB_IP_ADRS_HDSNN="$(aws ec2 describe-instances \
#  	--filters 'Name=tag:Name,Values=HadoopSecondaryNameNode' \
#  	--output text \
#  	--query 'Reservations[*].Instances[*].PublicIpAddress')"

# ssh -i ~/.ssh/irishkey.pem ubuntu@${PUB_IP_ADRS_HDNN} bash -c "'
# scp -i /home/ubuntu/irishkey.pem  /home/ubuntu/hadoop/conf/core-site.xml ubuntu@${PUB_IP_ADRS_HDSNN}:/home/ubuntu/hadoop/conf/
# '"
# ./hadoop_slave1.sh
# sleep 100
# ./hadoop_slave2.sh
# sleep 100




# sed -i '/<configuration>/ r test.xml' ./fool.xml
# ssh -i ~/.ssh/irishkey.pem ubuntu@${PUB_IP_ADRS_HDNN} sudo sed -i 's/# export JAVA_HOME=\/usr\/lib\/j2sdk1.5-sun/export JAVA_HOME=\/usr\/lib\/jvm\/java-7-oracle/g' $HADOOP_CONF/hadoop-env.sh 
#sed -i '/<configuration>/ r myxml.xml' /home/ubuntu/hadoop/conf/core-site.xml
# RUNNING="running"

# function sshi {

# TEST="$(aws ec2 describe-instances --filters 'Name=tag:Name,Values=s' --query 'Reservations[*].Instances[*].State' | awk '{print $2}')"

# if [ "$TEST" == "$RUNNING" ]
# then
#   echo "Count is running"
  
#   ssh -i ~/.ssh/irishkey.pem ubuntu@${PUB_IP_ADRS_HDNN}

# elif [ "$TEST" != "$RUNNING" ]
# then
# sleep 10
#   echo "not running"
#   sshi
  
# fi
# }

#  sshi

# HADOOPNODENAMEINSTID2="$(aws ec2 run-instances --image-id ami-f0b11187 --instance-type t2.micro --key-name  irishkey --security-groups  launch-wizard-7 --region eu-west-1 | grep INSTANCE | awk '{print $8}')"
# INETADDRS="$(ifconfig eth0 $1 | grep "inet addr" | awk -F: '{print $2}' | awk '{print $1}')"
# aws ec2 create-tags --resources ${HADOOPNODENAMEINSTID2} --tag Key=Name,Value=HadoopNameNode12
