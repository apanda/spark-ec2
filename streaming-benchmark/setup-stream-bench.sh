#!/bin/bash

pushd /root

git clone https://github.com/yahoo/streaming-benchmarks.git

pushd streaming-benchmarks

  # Install Maven
  pushd /root
  wget http://apache.go-parts.com/maven/maven-3/3.3.9/binaries/apache-maven-3.3.9-bin.tar.gz
  tar -xf apache-maven-3.3.9-bin.tar.gz
  popd

  # Fetch Kafka, Storm etc.
  MVN=/root/apache-maven-3.3.9/bin/mvn ./stream-bench.sh SETUP

  /root/spark-ec2/copy-dir /root/streaming-benchmarks

  # Setup zookeeper
  wget https://gist.githubusercontent.com/shivaram/0a853e25efc38a21fc84d1bf5d0011b8/raw/2708dfa23ea9c146eee09efe4ce3946cfb11470e/zookeeper.properties -O zookeeper.properties
  echo >> zookeeper.properties
  cat /root/spark-ec2/slaves | awk '{print "server."NR"="$1":2888:3888"}' >> zookeeper.properties
  cat /root/spark-ec2/masters | head -1 | awk '{print "server.0="$1":2888:3888"}' >> zookeeper.properties

  /root/spark-ec2/copy-dir /root/streaming-benchmarks/zookeeper.properties

  /root/spark/sbin/slaves.sh mkdir -p /mnt/zookeeper
  mkdir -p /mnt/zookeeper

  # Create a myid file here on each machine
  var=1
  for i in `cat /root/spark-ec2/slaves`
  do
    echo $var > /mnt/zookeeper-$var
    scp /mnt/zookeeper-$var $i:/mnt/zookeeper/myid
    var=$((var+1))
  done
  # Add driver as 0th replica
  echo 0 > /mnt/zookeeper/myid
  
# Start zookeeper
  $PWD/kafka_2.10-0.8.2.1/bin/zookeeper-server-start.sh -daemon $PWD/zookeeper.properties
  /root/spark/sbin/slaves.sh $PWD/kafka_2.10-0.8.2.1/bin/zookeeper-server-start.sh -daemon $PWD/zookeeper.properties

# Setup & configure Kafka

	wget https://gist.githubusercontent.com/shivaram/43d5c061428170b9b6c8f989e36d80aa/raw/f03ea8be218c17547691eb98c2e1cc72e7c94b0c/kafka.properties -O kafka.properties
  echo >> kafka.properties
	ZOOKEEPER_CONNECT=`cat /root/spark-ec2/slaves | awk '{ if (NR == 1) { printf("%s:2181", $1) } else { printf(",%s:2181", $1) } } END { printf("\n") }'`
	echo "zookeeper.connect=$ZOOKEEPER_CONNECT" >> kafka.properties
	#
	#Add broker id to Kafka
	var=1
	for i in `cat /root/spark-ec2/slaves`
	do
	  cp kafka.properties ./kafka-$var.properties
	  echo "broker.id=$var" >> ./kafka-$var.properties
	  scp ./kafka-$var.properties $i:/root/kafka.properties
	  var=$((var+1))
	done

# Start kafka

  /root/spark/sbin/slaves.sh $PWD/kafka_2.10-0.8.2.1/bin/kafka-server-start.sh -daemon /root/kafka.properties

popd

popd
~
