#!/bin/sh

CONFIG=~/.juju/openstack-config-ceph.yaml

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

#echo "Please reweight your OSDs, when they become available.  Run the following as root, on daisy:"
#echo
#echo "for i in 0 1 2; do ceph osd crush reweight osd.\$i 1; done"
#echo
#read -p "Press [Enter] when done..." input

# mysql
juju deploy --config $CONFIG mysql --to=2

# rabbitmq
juju deploy rabbitmq-server --to=1

# keystone
juju deploy --config $CONFIG keystone --to=1
juju add-relation keystone mysql

# nova
juju deploy --config $CONFIG nova-cloud-controller --to=1
juju add-relation nova-cloud-controller mysql
juju add-relation nova-cloud-controller rabbitmq-server
juju add-relation nova-cloud-controller keystone

# glance
juju deploy --config $CONFIG glance --to=1
juju add-relation glance mysql
juju add-relation glance nova-cloud-controller
juju add-relation glance ceph
juju add-relation glance keystone

# cinder
juju deploy --config $CONFIG cinder --to=1
juju add-relation cinder mysql
juju add-relation cinder keystone
juju add-relation cinder nova-cloud-controller
juju add-relation cinder rabbitmq-server
juju add-relation cinder ceph
juju add-relation cinder glance

# network node
juju deploy --config $CONFIG neutron-gateway --to=3
juju add-relation neutron-gateway mysql
juju add-relation neutron-gateway:amqp rabbitmq-server:amqp
juju add-relation neutron-gateway nova-cloud-controller

# compute nodes
juju deploy --config $CONFIG nova-compute --to=4
juju add-unit nova-compute --to=5
juju add-unit nova-compute --to=6
juju add-relation nova-compute mysql
juju add-relation nova-compute rabbitmq-server
juju add-relation nova-compute nova-cloud-controller
juju add-relation nova-compute glance
juju add-relation nova-compute ceph

# dashboard
juju deploy --config $CONFIG openstack-dashboard --to=1
juju add-relation openstack-dashboard keystone
