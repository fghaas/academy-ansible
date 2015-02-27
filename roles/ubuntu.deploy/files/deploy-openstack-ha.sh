#!/bin/sh

CONFIG=~/.juju/openstack-config-ha.yaml

juju_add() {
  fqdn="$1.`hostname -d`"
  semaphore=~/.juju/hosts/$fqdn
  if [ -e $semaphore ]; then
      echo "Skipping $fqdn because $semaphore exists"
  else
      juju add-machine ssh:$fqdn && touch $semaphore || exit 1
  fi
}

# Add nodes
juju_add alice
juju_add bob
juju_add charlie
juju_add daisy
juju_add eric
juju_add frank

# ceph
juju deploy --config $CONFIG ceph --to=4
juju add-unit ceph --to=5
juju add-unit ceph --to=6

echo "Please reweight your OSDs, when they become available.  Run the following as root, on daisy:"
echo
echo "for i in 0 1 2; do ceph osd crush reweight osd.\$i 1; done"
echo
read -p "Press [Enter] when done..." input

# mysql standalone
juju deploy --config $CONFIG mysql --to=2
juju add-relation mysql ceph

# mysql ha
juju deploy hacluster mysql-hacluster
juju add-relation mysql mysql-hacluster
juju add-unit mysql --to=2

# rabbitmq ha
juju deploy rabbitmq-server --to=1
juju add-unit rabbitmq-server --to=2

# keystone standalone
juju deploy --config $CONFIG keystone --to=1
juju add-relation keystone mysql

# keystone ha
juju deploy hacluster keystone-hacluster
juju add-relation keystone keystone-hacluster
juju add-unit keystone --to=2

# nova standalone
juju deploy --config $CONFIG nova-cloud-controller --to=1
juju add-relation nova-cloud-controller mysql
juju add-relation nova-cloud-controller rabbitmq-server
juju add-relation nova-cloud-controller keystone

# nova ha
juju deploy hacluster ncc-hacluster
juju add-relation nova-cloud-controller ncc-hacluster
juju add-unit nova-cloud-controller --to=2

# glance standalone
juju deploy --config $CONFIG glance --to=1
juju add-relation glance mysql
juju add-relation glance nova-cloud-controller
juju add-relation glance ceph
juju add-relation glance keystone

# glance ha
juju deploy hacluster glance-hacluster
juju add-relation glance glance-hacluster
juju add-unit glance --to=2

# cinder standalone
juju deploy --config $CONFIG cinder --to=1
juju add-relation cinder mysql
juju add-relation cinder keystone
juju add-relation cinder nova-cloud-controller
juju add-relation cinder rabbitmq-server
juju add-relation cinder ceph
juju add-relation cinder glance

# cinder ha
juju deploy hacluster cinder-hacluster
juju add-relation cinder cinder-hacluster
juju add-unit cinder --to=2

# network node
juju deploy --config $CONFIG quantum-gateway --to=3
juju add-relation quantum-gateway mysql
juju add-relation quantum-gateway:amqp rabbitmq-server:amqp
juju add-relation quantum-gateway nova-cloud-controller

# compute nodes
juju deploy --config $CONFIG nova-compute --to=4
juju add-unit nova-compute --to=5
juju add-unit nova-compute --to=6
juju add-relation nova-compute mysql
juju add-relation nova-compute rabbitmq-server
juju add-relation nova-compute nova-cloud-controller
juju add-relation nova-compute glance
juju add-relation nova-compute ceph

# dashboard standalone
juju deploy --config $CONFIG openstack-dashboard --to=1
juju add-relation openstack-dashboard keystone

# dashboard ha
juju deploy hacluster dashboard-hacluster
juju add-relation openstack-dashboard dashboard-hacluster
juju add-unit openstack-dashboard --to=2
