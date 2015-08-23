#!/bin/sh

set -x

CONFIG=~/.juju/openstack-config.yaml

juju_add() {
  fqdn="$1.`hostname -d`"
  semaphore=~/.juju/hosts/$fqdn
  if [ -e $semaphore ]; then
      echo "Skipping $fqdn because $semaphore exists"
  else
      juju add-machine ssh:$fqdn && touch $semaphore || exit 1
  fi
}

juju_add alice
juju_add bob
juju_add charlie
juju_add gina
juju_add harry
juju_add ian
juju_add julie
juju_add ken
juju_add laura


juju deploy rabbitmq-server --to=1
juju deploy mysql --to=2

juju deploy --config $CONFIG keystone --to=1
juju add-relation keystone mysql

juju deploy --config $CONFIG glance --to=4
juju add-relation glance mysql
juju add-relation glance keystone

juju deploy --config $CONFIG nova-cloud-controller --to=5
juju add-relation nova-cloud-controller mysql
juju add-relation nova-cloud-controller rabbitmq-server
juju add-relation nova-cloud-controller glance
juju add-relation nova-cloud-controller keystone

juju deploy --config $CONFIG nova-compute --to=2
juju add-relation nova-compute mysql
juju add-relation nova-compute rabbitmq-server
juju add-relation nova-compute glance
juju add-relation nova-compute nova-cloud-controller

juju deploy --config $CONFIG neutron-gateway --to=3
juju add-relation neutron-gateway mysql
juju add-relation neutron-gateway:amqp rabbitmq-server:amqp
juju add-relation neutron-gateway nova-cloud-controller


juju deploy --config $CONFIG neutron-api --to=6
juju deploy --config $CONFIG neutron-openvswitch
juju add-relation neutron-api keystone
juju add-relation neutron-api mysql
juju add-relation neutron-api rabbitmq-server
juju add-relation neutron-api neutron-openvswitch
juju add-relation neutron-api nova-cloud-controller

juju deploy --config $CONFIG cinder --to=7
juju add-relation cinder keystone
juju add-relation cinder mysql
juju add-relation cinder rabbitmq-server
juju add-relation cinder nova-cloud-controller

juju deploy --config $CONFIG openstack-dashboard --to=9
juju add-relation openstack-dashboard keystone

juju deploy heat --to=8
juju add-relation heat keystone
juju add-relation heat mysql
juju add-relation heat rabbitmq-server
